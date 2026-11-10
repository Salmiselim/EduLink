import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/evaluations_models.dart';
import 'evaluations_api_service.dart';

// ============================================================================
// SERVICE FIRESTORE — MODULE ÉVALUATIONS
// Jumeau du [EvaluationsApiService] : même surface de méthodes, mais les
// données vivent dans Cloud Firestore (collections `quizzes`, `quiz_attempts`,
// `assignments`, `submissions`, `documents`) au lieu d'un serveur REST.
//
// La logique « serveur » est reproduite côté client :
// - numérotation des tentatives et correction automatique (score ramené sur 20) ;
// - détection de retard (`isLate`) à la remise d'un devoir ;
// - filtrage des documents par `visibleFrom` pour les étudiants.
// Les documents utilisent exactement les clés du contrat JSON de l'API
// (dates en chaînes ISO) afin de rester compatibles avec le cache Hive.
// ============================================================================

class EvaluationsFirestoreService extends EvaluationsApiService {
  EvaluationsFirestoreService() : super(getToken: () async => null);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _cachedUid;
  String _cachedName = 'Utilisateur EduLink';
  String _cachedRole = 'student';

  CollectionReference<Map<String, dynamic>> get _quizzes => _db.collection('quizzes');
  CollectionReference<Map<String, dynamic>> get _attempts => _db.collection('quiz_attempts');
  CollectionReference<Map<String, dynamic>> get _assignments => _db.collection('assignments');
  CollectionReference<Map<String, dynamic>> get _submissions => _db.collection('submissions');
  CollectionReference<Map<String, dynamic>> get _documents => _db.collection('documents');
  CollectionReference<Map<String, dynamic>> get _enrollments => _db.collection('enrollments');

  /// Réinitialise le cache d'identité lors d'une déconnexion ou d'un changement de compte.
  void clearCachedIdentity() {
    _cachedUid = null;
    _cachedName = 'Utilisateur EduLink';
    _cachedRole = 'student';
  }

  /// Identité de l'utilisateur connecté (uid, nom, rôle depuis `users/{uid}`).
  Future<void> _ensureIdentity() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const EvalApiException(code: 401, message: 'Non connecté');
    }
    if (_cachedUid == user.uid) return;
    final doc = await _db.collection('users').doc(user.uid).get();
    _cachedUid = user.uid;
    _cachedName = (doc.data()?['name'] as String?) ?? user.displayName ?? 'Utilisateur EduLink';
    _cachedRole = (doc.data()?['role'] as String?) ?? 'student';
  }

  bool get _isTeacher => _cachedRole == 'teacher';

  /// Filtre excluant les documents marqués comme supprimés (soft-delete).
  bool _isNotDeleted(Map<String, dynamic> data) => data['isDeleted'] != true;

  /// Cours auxquels l'étudiant connecté est effectivement inscrit (`enrollments`).
  Future<Set<String>> _enrolledCourseIds() async {
    if (_cachedUid == null) return const {};
    try {
      final snap = await _enrollments
          .where('studentId', isEqualTo: _cachedUid)
          .get();
      return snap.docs
          .map((d) => d.data()['courseId'] as String?)
          .whereType<String>()
          .toSet();
    } catch (e) {
      debugPrint('[EvalFirestore] _enrolledCourseIds : $e');
      return const {};
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // QUIZ
  // ════════════════════════════════════════════════════════════════════════

  @override
  Future<List<Quiz>> getQuizzes({String? courseId}) async {
    await _ensureIdentity();
    if (_isTeacher) {
      // Isolation enseignant : uniquement les quiz créés par cet enseignant.
      Query<Map<String, dynamic>> query =
          _quizzes.where('teacherId', isEqualTo: _cachedUid);
      if (courseId != null) {
        query = query.where('courseId', isEqualTo: courseId);
      }
      final snap = await query.get();
      return snap.docs
          .where((d) => _isNotDeleted(d.data()))
          .map((d) => quizFromJsonPublic({'id': d.id, ...d.data()}))
          .toList();
    }
    // Mode étudiant : uniquement les quiz publiés des cours où il est inscrit.
    final enrolledIds = await _enrolledCourseIds();
    if (enrolledIds.isEmpty) return [];
    if (courseId != null && !enrolledIds.contains(courseId)) return [];
    Query<Map<String, dynamic>> query =
        _quizzes.where('isPublished', isEqualTo: true);
    if (courseId != null) {
      query = query.where('courseId', isEqualTo: courseId);
    }
    final snap = await query.get();
    return snap.docs
        .where((d) => _isNotDeleted(d.data()))
        .map((d) => quizFromJsonPublic({'id': d.id, ...d.data()}))
        .where((q) => q.isPublished && enrolledIds.contains(q.courseId))
        .toList();
  }

  @override
  Future<Quiz> getQuiz(String quizId) async {
    await _ensureIdentity();
    final doc = await _quizzes.doc(quizId).get();
    if (!doc.exists || !_isNotDeleted(doc.data()!)) {
      throw const EvalApiException(code: 404, message: 'Quiz introuvable');
    }
    return quizFromJsonPublic({'id': doc.id, ...doc.data()!});
  }

  @override
  Future<Quiz> createQuiz(Map<String, dynamic> body) async {
    await _ensureIdentity();
    final rawId = body['id'] as String?;
    final id = (rawId != null && rawId.isNotEmpty)
        ? rawId
        : 'quiz_${DateTime.now().millisecondsSinceEpoch}';
    final courseTitle = await _courseTitle(body['courseId'] as String?);
    final doc = {
      ...body,
      'id': id,
      'courseTitle': courseTitle,
      'teacherId': _cachedUid,
      'teacherName': _cachedName,
      'isDeleted': false,
      'questions': _questionsWithIds(body['questions'] as List?),
    };
    await _quizzes.doc(id).set(doc);
    return quizFromJsonPublic(doc);
  }

  @override
  Future<Quiz> updateQuiz(String quizId, Map<String, dynamic> body) async {
    await _ensureIdentity();
    final safeBody = <String, dynamic>{
      ...body,
      'teacherId': _cachedUid,
      'teacherName': _cachedName,
      'isDeleted': false,
    };
    safeBody['questions'] =
        _questionsWithIds(safeBody['questions'] as List?);
    if (safeBody['courseId'] != null) {
      safeBody['courseTitle'] =
          await _courseTitle(safeBody['courseId'] as String?);
    }
    await _quizzes.doc(quizId).update(safeBody);
    final doc = await _quizzes.doc(quizId).get();
    return quizFromJsonPublic({'id': quizId, ...doc.data()!});
  }

  @override
  Future<void> deleteQuiz(String quizId) async {
    await _ensureIdentity();
    final quizDoc = await _quizzes.doc(quizId).get();
    if (!quizDoc.exists) return;
    if (quizDoc.data()?['teacherId'] != _cachedUid) {
      throw const EvalApiException(
        code: 403,
        message: 'Vous ne pouvez supprimer que vos propres quiz.',
      );
    }
    // 1. Cascade sur les tentatives AVANT de supprimer le parent (les règles
    //    Firestore vérifient `get(.../quizzes/$(quizId)).data.teacherId`).
    try {
      final attempts =
          await _attempts.where('quizId', isEqualTo: quizId).get();
      for (final d in attempts.docs) {
        try {
          await d.reference.delete();
        } catch (e) {
          debugPrint('[EvalFirestore] deleteQuiz tentative ${d.id} : $e');
        }
      }
    } catch (e) {
      debugPrint('[EvalFirestore] deleteQuiz lecture tentatives : $e');
    }
    // Nettoyage des miroirs éventuels dans `submissions`.
    try {
      final mirrors =
          await _submissions.where('quizId', isEqualTo: quizId).get();
      for (final d in mirrors.docs) {
        try {
          await d.reference.delete();
        } catch (_) {}
      }
    } catch (_) {}

    // 2. Suppression du quiz : tente d'abord `.delete()` physique, puis
    //    bascule sur un soft-delete (`isDeleted: true`) si la règle Firestore
    //    `allow write: if request.resource.data.teacherId == request.auth.uid`
    //    bloque `delete` (car `request.resource` est null lors d'un delete).
    try {
      await _quizzes.doc(quizId).delete();
    } catch (_) {
      await _quizzes.doc(quizId).update({
        'isDeleted': true,
        'isPublished': false,
        'teacherId': _cachedUid,
      });
    }
  }

  @override
  Future<Quiz> publishQuiz(String quizId) async {
    await _ensureIdentity();
    final doc = await _quizzes.doc(quizId).get();
    if (!doc.exists) {
      throw const EvalApiException(code: 404, message: 'Quiz introuvable');
    }
    final current = (doc.data()!['isPublished'] as bool?) ?? false;
    await _quizzes.doc(quizId).update({
      'isPublished': !current,
      'teacherId': _cachedUid,
    });
    return quizFromJsonPublic({'id': quizId, ...doc.data()!, 'isPublished': !current});
  }

  /// Positionne explicitement l'état de publication (au lieu de basculer) :
  /// corrige le bug où « Publier » dans l'assistant écrivait `isPublished:
  /// true` puis le re-basculait en `false` lors de l'appel de publication.
  @override
  Future<Quiz> setQuizPublished(String quizId, {required bool published}) async {
    await _ensureIdentity();
    final doc = await _quizzes.doc(quizId).get();
    if (!doc.exists) {
      throw const EvalApiException(code: 404, message: 'Quiz introuvable');
    }
    await _quizzes.doc(quizId).update({
      'isPublished': published,
      'teacherId': _cachedUid,
    });
    return quizFromJsonPublic({'id': quizId, ...doc.data()!, 'isPublished': published});
  }

  /// Tentatives visibles : les siennes (étudiant) ou celles de ses quiz
  /// (enseignant, requêtes par paquets de 10 pour la limite `whereIn`).
  @override
  Future<List<QuizAttempt>> getVisibleAttempts() async {
    await _ensureIdentity();
    if (!_isTeacher) {
      final snap =
          await _attempts.where('studentId', isEqualTo: _cachedUid).get();
      return snap.docs
          .where((d) => _isNotDeleted(d.data()))
          .map((d) => _attemptFromDoc({'id': d.id, ...d.data()}))
          .toList();
    }
    final mine =
        await _quizzes.where('teacherId', isEqualTo: _cachedUid).get();
    final ids = mine.docs
        .where((d) => _isNotDeleted(d.data()))
        .map((d) => d.id)
        .toList();
    if (ids.isEmpty) return [];
    final out = <QuizAttempt>[];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.skip(i).take(10).toList();
      if (chunk.isEmpty) continue;
      try {
        final snap = await _attempts.where('quizId', whereIn: chunk).get();
        out.addAll(
          snap.docs
              .where((d) => _isNotDeleted(d.data()))
              .map((d) => _attemptFromDoc({'id': d.id, ...d.data()})),
        );
      } catch (_) {
        // Repli sur les miroirs de tentatives dans `submissions` lorsque
        // la règle `quiz_attempts` restreint la lecture à `studentId`.
        try {
          final mirrorSnap =
              await _submissions.where('quizId', whereIn: chunk).get();
          out.addAll(
            mirrorSnap.docs
                .where((d) =>
                    _isNotDeleted(d.data()) &&
                    d.data()['recordType'] == 'quiz_attempt')
                .map((d) => _attemptFromDoc({
                      'id': (d.data()['attemptId'] as String?) ?? d.id,
                      ...d.data(),
                    })),
          );
        } catch (e) {
          debugPrint('[EvalFirestore] getVisibleAttempts fallback : $e');
        }
      }
    }
    return out;
  }

  /// Copies visibles : les siennes (étudiant) ou celles de ses devoirs
  /// (enseignant).
  @override
  Future<List<Submission>> getVisibleSubmissions() async {
    await _ensureIdentity();
    if (!_isTeacher) {
      final snap =
          await _submissions.where('studentId', isEqualTo: _cachedUid).get();
      return snap.docs
          .where((d) =>
              _isNotDeleted(d.data()) &&
              d.data()['recordType'] != 'quiz_attempt' &&
              d.data()['assignmentId'] != null)
          .map((d) => _submissionFromDoc({'id': d.id, ...d.data()}))
          .toList();
    }
    final mine =
        await _assignments.where('teacherId', isEqualTo: _cachedUid).get();
    final ids = mine.docs
        .where((d) => _isNotDeleted(d.data()))
        .map((d) => d.id)
        .toList();
    if (ids.isEmpty) return [];
    final out = <Submission>[];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.skip(i).take(10).toList();
      if (chunk.isEmpty) continue;
      final snap =
          await _submissions.where('assignmentId', whereIn: chunk).get();
      out.addAll(
        snap.docs
            .where((d) =>
                _isNotDeleted(d.data()) &&
                d.data()['recordType'] != 'quiz_attempt')
            .map((d) => _submissionFromDoc({'id': d.id, ...d.data()})),
      );
    }
    return out;
  }

  /// Brouillon de questions généré localement (l'appel réel à Gemini se fera
  /// via une Cloud Function — le service externe reste utilisable en démo via
  /// le générateur du contrôleur).
  @override
  Future<List<Map<String, dynamic>>> generateQuizDraft({
    required String chapterText,
    required int questionCount,
  }) async {
    final count = questionCount.clamp(1, 10);
    return List.generate(count, (i) {
      return {
        'id': 'draft_${DateTime.now().millisecondsSinceEpoch}_$i',
        'type': 'qcm',
        'text': 'Question $i générée à partir de : ${chapterText.substring(0, chapterText.length.clamp(0, 60))}…',
        'options': ['Réponse A', 'Réponse B', 'Réponse C', 'Réponse D'],
        'correct': [0],
        'points': 2.0,
        'explanation': 'Brouillon à relire et corriger par l\'enseignant.',
      };
    });
  }

  // ════════════════════════════════════════════════════════════════════════
  // TENTATIVES
  // ════════════════════════════════════════════════════════════════════════

  @override
  Future<QuizAttempt> startAttempt(String quizId) async {
    await _ensureIdentity();
    final quizDoc = await _quizzes.doc(quizId).get();
    if (!quizDoc.exists) {
      throw EvalApiException(code: 404, message: 'Quiz introuvable');
    }
    final quiz = quizFromJsonPublic({'id': quizId, ...quizDoc.data()!});
    final existing =
        await _attempts.where('quizId', isEqualTo: quizId).where('studentId', isEqualTo: _cachedUid).get();
    final no = existing.docs.length + 1;
    final attempt = QuizAttempt(
      id: 'att_${_cachedUid}_${quizId}_$no',
      quizId: quizId,
      studentId: _cachedUid!,
      studentName: _cachedName,
      attemptNo: no,
      answers: List.generate(quiz.questions.length, (_) => <int>[]),
      startedAt: DateTime.now(),
    );
    await _attempts.doc(attempt.id).set(_attemptMap(attempt));
    return attempt;
  }

  @override
  Future<QuizAttempt> submitAttempt(
    String attemptId,
    List<List<int>> answers,
  ) async {
    await _ensureIdentity();
    final doc = await _attempts.doc(attemptId).get();
    if (!doc.exists) {
      throw EvalApiException(code: 404, message: 'Tentative introuvable');
    }
    final attempt = _attemptFromDoc({'id': attemptId, ...doc.data()!});
    final quizDoc = await _quizzes.doc(attempt.quizId).get();
    if (!quizDoc.exists) {
      throw EvalApiException(code: 404, message: 'Quiz introuvable');
    }
    final quiz = quizFromJsonPublic({'id': attempt.quizId, ...quizDoc.data()!});

    // Correction automatique : compare les indices triés à `question.correct`.
    double earned = 0;
    for (var q = 0; q < quiz.questions.length; q++) {
      final question = quiz.questions[q];
      final given = [...answers[q]]..sort();
      final expected = [...question.correct]..sort();
      if (listEquals(given, expected)) earned += question.points;
    }
    // Normalisation proportionnelle du score sur 20 à partir du barème total.
    final scoreSur20 =
        quiz.totalPoints == 0 ? 0.0 : (earned / quiz.totalPoints) * 20;
    final graded = attempt.copyWith(
      answers: answers,
      score: double.parse(scoreSur20.toStringAsFixed(1)),
      submittedAt: DateTime.now(),
    );
    await _attempts.doc(attemptId).update(_attemptMap(graded));
    // Miroir dans `submissions` (`recordType: 'quiz_attempt'`) pour permettre
    // à l'enseignant de lire les résultats et le carnet même si la règle
    // Firestore de `quiz_attempts` est restreinte à `studentId`.
    try {
      await _submissions.doc('quizatt_$attemptId').set({
        ..._attemptMap(graded),
        'attemptId': attemptId,
        'recordType': 'quiz_attempt',
      });
    } catch (_) {}
    return graded;
  }

  /// Statistiques agrégées par question pour l'enseignant.
  @override
  Future<Map<String, dynamic>> getQuizResults(String quizId) async {
    await _ensureIdentity();
    List<QuizAttempt> submitted = [];
    try {
      final attempts = await _attempts.where('quizId', isEqualTo: quizId).get();
      submitted = attempts.docs
          .where((d) => _isNotDeleted(d.data()))
          .map((d) => _attemptFromDoc({'id': d.id, ...d.data()}))
          .where((a) => a.isSubmitted)
          .toList();
    } catch (_) {
      try {
        final mirrors =
            await _submissions.where('quizId', isEqualTo: quizId).get();
        submitted = mirrors.docs
            .where((d) =>
                _isNotDeleted(d.data()) &&
                d.data()['recordType'] == 'quiz_attempt')
            .map((d) => _attemptFromDoc({
                  'id': (d.data()['attemptId'] as String?) ?? d.id,
                  ...d.data(),
                }))
            .where((a) => a.isSubmitted)
            .toList();
      } catch (_) {}
    }
    final scores = submitted.map((a) => a.score ?? 0.0).toList();
    final average = scores.isEmpty
        ? 0.0
        : scores.fold<double>(0, (t, s) => t + s) / scores.length;
    return {
      'quizId': quizId,
      'attemptsCount': submitted.length,
      'averageScore': double.parse(average.toStringAsFixed(1)),
      'scores': scores,
    };
  }

  // ════════════════════════════════════════════════════════════════════════
  // ASSIGNMENTS & SUBMISSIONS
  // ════════════════════════════════════════════════════════════════════════

  @override
  Future<List<Assignment>> getAssignments({String? courseId}) async {
    await _ensureIdentity();
    if (_isTeacher) {
      // Isolation enseignant : uniquement les devoirs créés par cet enseignant.
      Query<Map<String, dynamic>> query =
          _assignments.where('teacherId', isEqualTo: _cachedUid);
      if (courseId != null) {
        query = query.where('courseId', isEqualTo: courseId);
      }
      final snap = await query.get();
      return snap.docs
          .where((d) => _isNotDeleted(d.data()))
          .map((d) => _assignmentFromDoc({'id': d.id, ...d.data()}))
          .toList();
    }
    // Mode étudiant : uniquement les devoirs des cours auxquels il est inscrit.
    final enrolledIds = await _enrolledCourseIds();
    if (enrolledIds.isEmpty) return [];
    if (courseId != null && !enrolledIds.contains(courseId)) return [];
    Query<Map<String, dynamic>> query = _assignments;
    if (courseId != null) {
      query = query.where('courseId', isEqualTo: courseId);
    }
    final snap = await query.get();
    return snap.docs
        .where((d) => _isNotDeleted(d.data()))
        .map((d) => _assignmentFromDoc({'id': d.id, ...d.data()}))
        .where((a) => enrolledIds.contains(a.courseId))
        .toList();
  }

  @override
  Future<Assignment> getAssignment(String assignmentId) async {
    await _ensureIdentity();
    final doc = await _assignments.doc(assignmentId).get();
    if (!doc.exists || !_isNotDeleted(doc.data()!)) {
      throw const EvalApiException(code: 404, message: 'Devoir introuvable');
    }
    return _assignmentFromDoc({'id': assignmentId, ...doc.data()!});
  }

  @override
  Future<Assignment> createAssignment(Map<String, dynamic> body) async {
    await _ensureIdentity();
    final rawId = body['id'] as String?;
    final id = (rawId != null && rawId.isNotEmpty)
        ? rawId
        : 'assign_${DateTime.now().millisecondsSinceEpoch}';
    final courseTitle = await _courseTitle(body['courseId'] as String?);
    final doc = {
      ...body,
      'id': id,
      'courseTitle': courseTitle,
      'teacherId': _cachedUid,
      'teacherName': _cachedName,
      'isDeleted': false,
    };
    await _assignments.doc(id).set(doc);
    return _assignmentFromDoc(doc);
  }

  @override
  Future<Assignment> updateAssignment(
    String assignmentId,
    Map<String, dynamic> body,
  ) async {
    await _ensureIdentity();
    final enriched = <String, dynamic>{
      ...body,
      'teacherId': _cachedUid,
      'teacherName': _cachedName,
      'isDeleted': false,
    };
    if (enriched['courseId'] != null) {
      enriched['courseTitle'] =
          await _courseTitle(enriched['courseId'] as String?);
    }
    await _assignments.doc(assignmentId).update(enriched);
    final doc = await _assignments.doc(assignmentId).get();
    return _assignmentFromDoc({'id': assignmentId, ...doc.data()!});
  }

  @override
  Future<void> deleteAssignment(String assignmentId) async {
    await _ensureIdentity();
    final asgDoc = await _assignments.doc(assignmentId).get();
    if (!asgDoc.exists) return;
    if (asgDoc.data()?['teacherId'] != _cachedUid) {
      throw const EvalApiException(
        code: 403,
        message: 'Vous ne pouvez supprimer que vos propres devoirs.',
      );
    }
    // 1. Cascade sur les copies AVANT la suppression du devoir parent.
    try {
      final subs = await _submissions
          .where('assignmentId', isEqualTo: assignmentId)
          .get();
      for (final d in subs.docs) {
        try {
          await d.reference.delete();
        } catch (e) {
          debugPrint('[EvalFirestore] deleteAssignment copie ${d.id} : $e');
        }
      }
    } catch (e) {
      debugPrint('[EvalFirestore] deleteAssignment lecture copies : $e');
    }
    // 2. Suppression physique avec repli soft-delete (`isDeleted: true`).
    try {
      await _assignments.doc(assignmentId).delete();
    } catch (_) {
      await _assignments.doc(assignmentId).update({
        'isDeleted': true,
        'teacherId': _cachedUid,
      });
    }
  }

  @override
  Future<Submission> submitAssignment({
    required String assignmentId,
    required List<String> fileUrls,
    required String comment,
  }) async {
    await _ensureIdentity();
    final assignmentDoc = await _assignments.doc(assignmentId).get();
    if (!assignmentDoc.exists || !_isNotDeleted(assignmentDoc.data()!)) {
      throw const EvalApiException(code: 404, message: 'Devoir introuvable');
    }
    final assignment = _assignmentFromDoc({'id': assignmentId, ...assignmentDoc.data()!});
    final now = DateTime.now();
    final isLate = now.isAfter(assignment.dueDate);
    final existing = await _submissions
        .where('assignmentId', isEqualTo: assignmentId)
        .where('studentId', isEqualTo: _cachedUid)
        .get();
    final submission = Submission(
      id: 'sub_${_cachedUid}_${assignmentId}_${existing.docs.length + 1}',
      assignmentId: assignmentId,
      studentId: _cachedUid!,
      studentName: _cachedName,
      fileUrls: fileUrls,
      comment: comment,
      submittedAt: now,
      isLate: isLate,
      status: SubmissionStatus.submitted,
    );
    await _submissions.doc(submission.id).set(_submissionMap(submission));
    return submission;
  }

  @override
  Future<List<Submission>> getSubmissions(String assignmentId) async {
    await _ensureIdentity();
    final snap = await _submissions.where('assignmentId', isEqualTo: assignmentId).get();
    return snap.docs
        .where((d) =>
            _isNotDeleted(d.data()) &&
            d.data()['recordType'] != 'quiz_attempt')
        .map((d) => _submissionFromDoc({'id': d.id, ...d.data()}))
        .toList();
  }

  @override
  Future<Submission> getSubmission(String submissionId) async {
    await _ensureIdentity();
    final doc = await _submissions.doc(submissionId).get();
    if (!doc.exists || !_isNotDeleted(doc.data()!)) {
      throw const EvalApiException(code: 404, message: 'Copie introuvable');
    }
    return _submissionFromDoc({'id': submissionId, ...doc.data()!});
  }

  @override
  Future<Submission> gradeSubmission({
    required String submissionId,
    required double grade,
    required String feedback,
  }) async {
    await _ensureIdentity();
    await _submissions.doc(submissionId).update({
      'grade': grade,
      'feedback': feedback,
      'gradedAt': DateTime.now().toIso8601String(),
      'status': 'graded',
    });
    final doc = await _submissions.doc(submissionId).get();
    return _submissionFromDoc({'id': submissionId, ...doc.data()!});
  }

  // ════════════════════════════════════════════════════════════════════════
  // DOCUMENTS
  // ════════════════════════════════════════════════════════════════════════

  @override
  Future<List<CourseDocument>> getDocuments({String? courseId}) async {
    await _ensureIdentity();
    if (_isTeacher) {
      // Isolation enseignant : uniquement les documents créés par cet enseignant.
      Query<Map<String, dynamic>> query =
          _documents.where('teacherId', isEqualTo: _cachedUid);
      if (courseId != null) {
        query = query.where('courseId', isEqualTo: courseId);
      }
      final snap = await query.get();
      return snap.docs
          .where((d) => _isNotDeleted(d.data()))
          .map((d) => _documentFromDoc({'id': d.id, ...d.data()}))
          .toList();
    }
    // Mode étudiant : uniquement les documents des cours auxquels il est inscrit
    // et dont la date de visibilité est atteinte.
    final enrolledIds = await _enrolledCourseIds();
    if (enrolledIds.isEmpty) return [];
    if (courseId != null && !enrolledIds.contains(courseId)) return [];
    Query<Map<String, dynamic>> query = _documents;
    if (courseId != null) {
      query = query.where('courseId', isEqualTo: courseId);
    }
    final snap = await query.get();
    final now = DateTime.now();
    return snap.docs
        .where((d) => _isNotDeleted(d.data()))
        .map((d) => _documentFromDoc({'id': d.id, ...d.data()}))
        .where((d) =>
            enrolledIds.contains(d.courseId) && !d.visibleFrom.isAfter(now))
        .toList();
  }

  @override
  Future<CourseDocument> createDocument(Map<String, dynamic> body) async {
    await _ensureIdentity();
    final rawId = body['id'] as String?;
    final id = (rawId != null && rawId.isNotEmpty)
        ? rawId
        : 'doc_${DateTime.now().millisecondsSinceEpoch}';
    final courseTitle = await _courseTitle(body['courseId'] as String?);
    final doc = {
      ...body,
      'id': id,
      'courseTitle': courseTitle,
      'teacherId': _cachedUid,
      'teacherName': _cachedName,
      'isDeleted': false,
    };
    await _documents.doc(id).set(doc);
    return _documentFromDoc(doc);
  }

  @override
  Future<CourseDocument> updateDocument(
    String documentId,
    Map<String, dynamic> body,
  ) async {
    await _ensureIdentity();
    final enriched = <String, dynamic>{...body};
    if (_isTeacher) {
      enriched['teacherId'] = _cachedUid;
      enriched['teacherName'] = _cachedName;
      enriched['isDeleted'] = false;
    }
    if (enriched['courseId'] != null) {
      enriched['courseTitle'] =
          await _courseTitle(enriched['courseId'] as String?);
    }
    await _documents.doc(documentId).update(enriched);
    final doc = await _documents.doc(documentId).get();
    return _documentFromDoc({'id': documentId, ...doc.data()!});
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    await _ensureIdentity();
    final docSnap = await _documents.doc(documentId).get();
    if (!docSnap.exists) return;
    if (docSnap.data()?['teacherId'] != _cachedUid) {
      throw const EvalApiException(
        code: 403,
        message: 'Vous ne pouvez supprimer que vos propres documents.',
      );
    }
    try {
      await _documents.doc(documentId).delete();
    } catch (_) {
      await _documents.doc(documentId).update({
        'isDeleted': true,
        'teacherId': _cachedUid,
      });
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // GRADEBOOK & UPCOMING
  // ════════════════════════════════════════════════════════════════════════

  /// Carnet de notes consolidé : tentatives de quiz + copies de devoirs
  /// du cours, agrégées par étudiant.
  @override
  Future<List<GradebookRow>> getGradebook(String courseId) async {
    await _ensureIdentity();
    final rows = <GradebookRow>[];

    final quizzes = await _quizzes.where('courseId', isEqualTo: courseId).get();
    for (final q in quizzes.docs) {
      if (!_isNotDeleted(q.data())) continue;
      if (_isTeacher && q.data()['teacherId'] != _cachedUid) continue;
      List<QuizAttempt> quizAttempts = [];
      if (!_isTeacher) {
        try {
          final snap = await _attempts
              .where('quizId', isEqualTo: q.id)
              .where('studentId', isEqualTo: _cachedUid)
              .get();
          quizAttempts = snap.docs
              .where((d) => _isNotDeleted(d.data()))
              .map((d) => _attemptFromDoc({'id': d.id, ...d.data()}))
              .toList();
        } catch (_) {}
      } else {
        try {
          final snap = await _attempts.where('quizId', isEqualTo: q.id).get();
          quizAttempts = snap.docs
              .where((d) => _isNotDeleted(d.data()))
              .map((d) => _attemptFromDoc({'id': d.id, ...d.data()}))
              .toList();
        } catch (_) {
          try {
            final mirrors =
                await _submissions.where('quizId', isEqualTo: q.id).get();
            quizAttempts = mirrors.docs
                .where((d) =>
                    _isNotDeleted(d.data()) &&
                    d.data()['recordType'] == 'quiz_attempt')
                .map((d) => _attemptFromDoc({
                      'id': (d.data()['attemptId'] as String?) ?? d.id,
                      ...d.data(),
                    }))
                .toList();
          } catch (_) {}
        }
      }
      for (final attempt in quizAttempts) {
        if (!attempt.isSubmitted) continue;
        rows.add(GradebookRow(
          studentId: attempt.studentId,
          studentName: attempt.studentName,
          courseTitle: (q.data()['courseTitle'] as String?) ?? '',
          itemType: 'quiz',
          itemTitle: (q.data()['title'] as String?) ?? 'Quiz',
          grade: attempt.score,
          maxGrade: 20,
          status: 'graded',
          datedAt: attempt.submittedAt,
        ));
      }
    }

    final assignments =
        await _assignments.where('courseId', isEqualTo: courseId).get();
    for (final a in assignments.docs) {
      if (!_isNotDeleted(a.data())) continue;
      if (_isTeacher && a.data()['teacherId'] != _cachedUid) continue;
      try {
        Query<Map<String, dynamic>> subQuery =
            _submissions.where('assignmentId', isEqualTo: a.id);
        if (!_isTeacher) {
          subQuery = subQuery.where('studentId', isEqualTo: _cachedUid);
        }
        final subs = await subQuery.get();
        for (final s in subs.docs) {
          if (!_isNotDeleted(s.data()) ||
              s.data()['recordType'] == 'quiz_attempt') {
            continue;
          }
          final submission = _submissionFromDoc({'id': s.id, ...s.data()});
          rows.add(GradebookRow(
            studentId: submission.studentId,
            studentName: submission.studentName,
            courseTitle: (a.data()['courseTitle'] as String?) ?? '',
            itemType: 'devoir',
            itemTitle: (a.data()['title'] as String?) ?? 'Devoir',
            grade: submission.grade,
            maxGrade: (a.data()['maxGrade'] as num? ?? 20).toDouble(),
            status: submission.status == SubmissionStatus.graded
                ? 'graded'
                : 'pending',
            datedAt: submission.submittedAt,
          ));
        }
      } catch (_) {}
    }
    return rows;
  }

  /// Évaluations à venir : quiz et devoirs dont l'échéance n'est pas passée,
  /// filtrés par enseignant propriétaire ou cours inscrits de l'étudiant.
  @override
  Future<List<Map<String, dynamic>>> getUpcoming() async {
    await _ensureIdentity();
    final now = DateTime.now();
    final items = <Map<String, dynamic>>[];
    final enrolledIds = _isTeacher ? const <String>{} : await _enrolledCourseIds();
    if (!_isTeacher && enrolledIds.isEmpty) return [];

    final quizzes = _isTeacher
        ? await _quizzes.where('teacherId', isEqualTo: _cachedUid).get()
        : await _quizzes.where('isPublished', isEqualTo: true).get();
    for (final q in quizzes.docs) {
      if (!_isNotDeleted(q.data())) continue;
      final courseId = (q.data()['courseId'] as String?) ?? '';
      if (!_isTeacher && !enrolledIds.contains(courseId)) continue;
      final due =
          DateTime.tryParse((q.data()['dueDate'] as String?) ?? '') ?? now;
      if (due.isAfter(now)) {
        items.add({
          'type': 'quiz',
          'title': (q.data()['title'] as String?) ?? 'Quiz',
          'courseTitle': (q.data()['courseTitle'] as String?) ?? '',
          'dueDate': (q.data()['dueDate'] as String?) ?? due.toIso8601String(),
        });
      }
    }
    final assignments = _isTeacher
        ? await _assignments.where('teacherId', isEqualTo: _cachedUid).get()
        : await _assignments.get();
    for (final a in assignments.docs) {
      if (!_isNotDeleted(a.data())) continue;
      final courseId = (a.data()['courseId'] as String?) ?? '';
      if (!_isTeacher && !enrolledIds.contains(courseId)) continue;
      final due =
          DateTime.tryParse((a.data()['dueDate'] as String?) ?? '') ?? now;
      if (due.isAfter(now)) {
        items.add({
          'type': 'devoir',
          'title': (a.data()['title'] as String?) ?? 'Devoir',
          'courseTitle': (a.data()['courseTitle'] as String?) ?? '',
          'dueDate': (a.data()['dueDate'] as String?) ?? due.toIso8601String(),
        });
      }
    }
    items.sort(
      (a, b) => (a['dueDate'] as String).compareTo(b['dueDate'] as String),
    );
    return items;
  }

  // ════════════════════════════════════════════════════════════════════════
  // MAPPING (mêmes clés que le contrat JSON de l'API)
  // ════════════════════════════════════════════════════════════════════════

  /// Garantit un `id` stable pour chaque question (les body du contrôleur
  /// n'en contiennent pas — l'index sert de repli).
  List<Map<String, dynamic>> _questionsWithIds(List? questions) {
    final list = questions ?? const [];
    return [
      for (var i = 0; i < list.length; i++)
        {
          ...(list[i] as Map<String, dynamic>),
          'id': ((list[i] as Map<String, dynamic>)['id'] as String?) ?? 'q_$i',
        },
    ];
  }

  /// Complète `courseTitle` depuis la collection `courses` (liaison L4).
  Future<String> _courseTitle(String? courseId) async {
    if (courseId == null) return '';
    final doc = await _db.collection('courses').doc(courseId).get();
    return (doc.data()?['title'] as String?) ?? '';
  }

  Map<String, dynamic> _attemptMap(QuizAttempt a) => {
        'quizId': a.quizId,
        'studentId': a.studentId,
        'studentName': a.studentName,
        'attemptNo': a.attemptNo,
        'answers': a.answers,
        'score': a.score,
        'startedAt': a.startedAt.toIso8601String(),
        'submittedAt': a.submittedAt?.toIso8601String(),
      };

  QuizAttempt _attemptFromDoc(Map<String, dynamic> j) => QuizAttempt(
        id: j['id'] as String,
        quizId: j['quizId'] as String,
        studentId: j['studentId'] as String,
        studentName: j['studentName'] as String? ?? '',
        attemptNo: (j['attemptNo'] as num).toInt(),
        answers: (j['answers'] as List? ?? [])
            .map((a) => (a as List).cast<int>())
            .toList(),
        score: j['score'] != null ? (j['score'] as num).toDouble() : null,
        startedAt: DateTime.parse(j['startedAt'] as String),
        submittedAt: j['submittedAt'] != null
            ? DateTime.parse(j['submittedAt'] as String)
            : null,
      );

  Map<String, dynamic> _submissionMap(Submission s) => {
        'assignmentId': s.assignmentId,
        'studentId': s.studentId,
        'studentName': s.studentName,
        'fileUrls': s.fileUrls,
        'comment': s.comment,
        'submittedAt': s.submittedAt.toIso8601String(),
        'isLate': s.isLate,
        'status': s.status.name,
        'grade': s.grade,
        'feedback': s.feedback,
        'gradedAt': s.gradedAt?.toIso8601String(),
      };

  Submission _submissionFromDoc(Map<String, dynamic> j) => Submission(
        id: j['id'] as String,
        assignmentId: j['assignmentId'] as String,
        studentId: j['studentId'] as String,
        studentName: j['studentName'] as String? ?? '',
        fileUrls: (j['fileUrls'] as List? ?? []).cast<String>(),
        comment: j['comment'] as String? ?? '',
        submittedAt: DateTime.parse(j['submittedAt'] as String),
        isLate: j['isLate'] as bool? ?? false,
        status: (j['status'] as String?) == 'graded'
            ? SubmissionStatus.graded
            : SubmissionStatus.submitted,
        grade: j['grade'] != null ? (j['grade'] as num).toDouble() : null,
        feedback: j['feedback'] as String?,
        gradedAt: j['gradedAt'] != null
            ? DateTime.parse(j['gradedAt'] as String)
            : null,
      );

  Assignment _assignmentFromDoc(Map<String, dynamic> j) => Assignment(
        id: j['id'] as String,
        courseId: j['courseId'] as String,
        courseTitle: j['courseTitle'] as String? ?? '',
        teacherId: j['teacherId'] as String,
        teacherName: j['teacherName'] as String? ?? '',
        title: j['title'] as String,
        instructions: j['instructions'] as String? ?? '',
        attachments: (j['attachments'] as List? ?? []).cast<String>(),
        dueDate: DateTime.parse(j['dueDate'] as String),
        maxGrade: (j['maxGrade'] as num).toDouble(),
        allowLate: j['allowLate'] as bool? ?? false,
      );

  CourseDocument _documentFromDoc(Map<String, dynamic> j) {
    final folderStr = j['folder'] as String? ?? 'polycopies';
    final folder = DocumentFolder.values.firstWhere(
      (f) => f.name == folderStr,
      orElse: () => DocumentFolder.polycopies,
    );
    return CourseDocument(
      id: j['id'] as String,
      courseId: j['courseId'] as String,
      courseTitle: j['courseTitle'] as String? ?? '',
      teacherId: j['teacherId'] as String,
      teacherName: j['teacherName'] as String? ?? '',
      title: j['title'] as String,
      description: j['description'] as String? ?? '',
      folder: folder,
      fileUrl: j['fileUrl'] as String? ?? '',
      order: (j['order'] as num? ?? 0).toInt(),
      visibleFrom: DateTime.parse(j['visibleFrom'] as String),
      downloadsCount: (j['downloadsCount'] as num? ?? 0).toInt(),
    );
  }
}
