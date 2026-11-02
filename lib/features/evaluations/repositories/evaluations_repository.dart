import 'package:flutter/foundation.dart';
import '../models/evaluations_models.dart';
import '../services/evaluations_api_service.dart';
import '../services/evaluations_local_service.dart';

/// Couche repository du module Évaluations.
///
/// Source de vérité unique entre l'API REST et le cache local Hive.
///
/// Responsabilités :
///   - Stratégie fetch-then-cache : retourne le cache offline si le réseau échoue.
///   - Logique métier L2 : déclenche [_checkAndGrantBadge] après quiz réussi,
///     devoir remis à temps ou copies corrigées (stub — à brancher sur M1).
///   - Logique métier L4 : les quiz et devoirs sont toujours filtrés par [courseId].
///   - Logique métier L8 : stub FCM notification après publication d'une note.
class EvaluationsRepository {
  final EvaluationsApiService _api;
  final EvaluationsLocalService _local;

  /// Identifiant de l'utilisateur connecté (étudiant ou enseignant).
  String currentUserId;
  String currentUserName;
  UserRole currentUserRole;

  EvaluationsRepository({
    required EvaluationsApiService api,
    required EvaluationsLocalService local,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserRole,
  })  : _api = api,
        _local = local;

  // ════════════════════════════════════════════════════════════════════════
  // INITIALISATION
  // ════════════════════════════════════════════════════════════════════════

  /// Ouvre les boîtes Hive. Appelé au démarrage dans [EvaluationsController].
  Future<void> init() => _local.init();

  // ════════════════════════════════════════════════════════════════════════
  // QUIZ
  // ════════════════════════════════════════════════════════════════════════

  /// Retourne la liste des quiz, mise en cache pour un accès hors-ligne.
  /// Liaison L4 : filtrée par [courseId] si fourni.
  Future<List<Quiz>> getQuizzes({String? courseId}) async {
    try {
      final quizzes = await _api.getQuizzes(courseId: courseId);
      // Sérialisation légère pour le cache (on stocke le JSON brut reçu).
      await _local.cacheQuizList(
        quizzes.map(_quizToJson).toList(),
      );
      return quizzes;
    } on EvalApiException catch (e) {
      debugPrint('[Repo] getQuizzes hors-ligne : $e');
      // Fallback cache Hive
      return _local
          .getCachedQuizList()
          .map((j) => _api.quizFromJsonPublic(j))
          .toList();
    }
  }

  Future<Quiz> getQuiz(String quizId) => _api.getQuiz(quizId);

  Future<Quiz> createQuiz(Map<String, dynamic> body) =>
      _api.createQuiz(body);

  Future<Quiz> updateQuiz(String quizId, Map<String, dynamic> body) =>
      _api.updateQuiz(quizId, body);

  Future<void> deleteQuiz(String quizId) => _api.deleteQuiz(quizId);

  Future<Quiz> publishQuiz(String quizId) => _api.publishQuiz(quizId);

  /// Génère un brouillon de quiz via Gemini (L — API externe).
  Future<List<Map<String, dynamic>>> generateQuizDraft({
    required String chapterText,
    required int questionCount,
  }) =>
      _api.generateQuizDraft(
        chapterText: chapterText,
        questionCount: questionCount,
      );

  // ── Tentatives ──────────────────────────────────────────────────────────

  /// Démarre une tentative et retourne l'objet tentative initial.
  Future<QuizAttempt> startAttempt(String quizId) =>
      _api.startAttempt(quizId);

  /// Sauvegarde les réponses intermédiaires localement (survie au crash).
  Future<void> saveDraftAnswers({
    required String attemptId,
    required List<List<int>> answers,
  }) =>
      _local.saveDraftAttempt(attemptId: attemptId, answers: answers);

  /// Lit les réponses brouillon pour récupérer une session après un crash.
  List<List<int>>? getDraftAnswers(String attemptId) {
    final draft = _local.getDraftAttempt(attemptId);
    if (draft == null) return null;
    return (draft['answers'] as List)
        .map((a) => (a as List).cast<int>())
        .toList();
  }

  /// Soumet la tentative, déclenche la logique badge L2 si score ≥ 10/20.
  Future<QuizAttempt> submitAttempt(
    String attemptId,
    List<List<int>> answers,
  ) async {
    final attempt = await _api.submitAttempt(attemptId, answers);
    // Nettoie le brouillon local après soumission réussie.
    await _local.clearDraftAttempt(attemptId);
    // L2 — Badge : quiz réussi (score ≥ 10/20).
    if ((attempt.score ?? 0) >= 10) {
      await _checkAndGrantBadge(
        userId: currentUserId,
        metric: 'quiz_success',
        value: attempt.score ?? 0,
      );
    }
    return attempt;
  }

  Future<Map<String, dynamic>> getQuizResults(String quizId) =>
      _api.getQuizResults(quizId);

  // ════════════════════════════════════════════════════════════════════════
  // ASSIGNMENTS
  // ════════════════════════════════════════════════════════════════════════

  /// Liaison L4 : filtrée par [courseId] si fourni.
  Future<List<Assignment>> getAssignments({String? courseId}) =>
      _api.getAssignments(courseId: courseId);

  Future<Assignment> getAssignment(String assignmentId) =>
      _api.getAssignment(assignmentId);

  Future<Assignment> createAssignment(Map<String, dynamic> body) =>
      _api.createAssignment(body);

  Future<Assignment> updateAssignment(
    String assignmentId,
    Map<String, dynamic> body,
  ) =>
      _api.updateAssignment(assignmentId, body);

  Future<void> deleteAssignment(String assignmentId) =>
      _api.deleteAssignment(assignmentId);

  // ── Submissions ──────────────────────────────────────────────────────────

  /// Dépose une copie. Déclenche badge L2 si rendu à temps.
  Future<Submission> submitAssignment({
    required String assignmentId,
    required List<String> fileUrls,
    required String comment,
  }) async {
    final sub = await _api.submitAssignment(
      assignmentId: assignmentId,
      fileUrls: fileUrls,
      comment: comment,
    );
    // L2 — Badge : devoir rendu à temps.
    if (!sub.isLate) {
      await _checkAndGrantBadge(
        userId: currentUserId,
        metric: 'assignment_on_time',
        value: 1,
      );
    }
    return sub;
  }

  Future<List<Submission>> getSubmissions(String assignmentId) =>
      _api.getSubmissions(assignmentId);

  Future<Submission> getSubmission(String submissionId) =>
      _api.getSubmission(submissionId);

  /// Note une copie. L8 : notifie l'étudiant. L2 : badge copies corrigées.
  Future<Submission> gradeSubmission({
    required String submissionId,
    required double grade,
    required String feedback,
  }) async {
    final sub = await _api.gradeSubmission(
      submissionId: submissionId,
      grade: grade,
      feedback: feedback,
    );
    // L8 — Notification FCM : note publiée (stub — brancher M1/NotificationsService).
    await _sendFcmNotification(
      userId: sub.studentId,
      title: 'Votre copie a été corrigée',
      body: 'Note obtenue : ${grade.toStringAsFixed(1)} / ${sub.grade ?? 20}',
    );
    // L2 — Badge : copies corrigées.
    await _checkAndGrantBadge(
      userId: currentUserId,
      metric: 'submissions_graded',
      value: 1,
    );
    return sub;
  }

  // ════════════════════════════════════════════════════════════════════════
  // DOCUMENTS
  // ════════════════════════════════════════════════════════════════════════

  Future<List<CourseDocument>> getDocuments({String? courseId}) =>
      _api.getDocuments(courseId: courseId);

  Future<CourseDocument> createDocument(Map<String, dynamic> body) =>
      _api.createDocument(body);

  Future<CourseDocument> updateDocument(
    String documentId,
    Map<String, dynamic> body,
  ) =>
      _api.updateDocument(documentId, body);

  Future<void> deleteDocument(String documentId) =>
      _api.deleteDocument(documentId);

  // ════════════════════════════════════════════════════════════════════════
  // GRADEBOOK & UPCOMING
  // ════════════════════════════════════════════════════════════════════════

  /// Carnet de notes avec fallback cache Hive si hors-ligne.
  Future<List<GradebookRow>> getGradebook(String courseId) async {
    try {
      final rows = await _api.getGradebook(courseId);
      await _local.cacheGradebook(
        courseId,
        rows.map(_gradebookRowToJson).toList(),
      );
      return rows;
    } on EvalApiException catch (e) {
      debugPrint('[Repo] getGradebook hors-ligne : $e');
      return _local
          .getCachedGradebook(courseId)
          .map(_gradebookRowFromJsonPublic)
          .toList();
    }
  }

  /// Évaluations à venir avec fallback cache Hive si hors-ligne.
  Future<List<Map<String, dynamic>>> getUpcoming() async {
    try {
      final items = await _api.getUpcoming();
      await _local.cacheUpcoming(currentUserId, items);
      return items;
    } on EvalApiException catch (e) {
      debugPrint('[Repo] getUpcoming hors-ligne : $e');
      return _local.getCachedUpcoming(currentUserId);
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // LIAISONS L2 & L8 — STUBS
  // ════════════════════════════════════════════════════════════════════════

  /// L2 — Liaison Badges : appelle BadgesService.checkAndGrant(userId, metric, value).
  /// En production, remplacer par un appel HTTP vers l'endpoint M1.
  Future<void> _checkAndGrantBadge({
    required String userId,
    required String metric,
    required double value,
  }) async {
    debugPrint('[L2-Badges] checkAndGrant(userId=$userId, metric=$metric, value=$value)');
    // TODO: _api.post('/badges/check', data: {'userId': userId, 'metric': metric, 'value': value})
  }

  /// L8 — Liaison FCM : appelle NotificationsService.send(userId, payload).
  /// En production, remplacer par un appel HTTP vers l'endpoint M1.
  Future<void> _sendFcmNotification({
    required String userId,
    required String title,
    required String body,
  }) async {
    debugPrint('[L8-FCM] send(userId=$userId, title=$title)');
    // TODO: _api.post('/notifications/send', data: {'userId': userId, 'title': title, 'body': body})
  }

  // ════════════════════════════════════════════════════════════════════════
  // SÉRIALISATION LÉGÈRE (pour le cache Hive)
  // ════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _quizToJson(Quiz q) => {
        'id': q.id,
        'courseId': q.courseId,
        'courseTitle': q.courseTitle,
        'teacherId': q.teacherId,
        'teacherName': q.teacherName,
        'title': q.title,
        'timeLimitMin': q.timeLimitMin,
        'attemptsAllowed': q.attemptsAllowed,
        'availableFrom': q.availableFrom.toIso8601String(),
        'dueDate': q.dueDate.toIso8601String(),
        'isPublished': q.isPublished,
        'questions': q.questions
            .map((qu) => {
                  'id': qu.id,
                  'type': qu.type.code,
                  'text': qu.text,
                  'options': qu.options,
                  'correct': qu.correct,
                  'points': qu.points,
                  'explanation': qu.explanation,
                })
            .toList(),
      };

  Map<String, dynamic> _gradebookRowToJson(GradebookRow r) => {
        'studentId': r.studentId,
        'studentName': r.studentName,
        'courseTitle': r.courseTitle,
        'itemType': r.itemType,
        'itemTitle': r.itemTitle,
        'grade': r.grade,
        'maxGrade': r.maxGrade,
        'status': r.status,
        'datedAt': r.datedAt?.toIso8601String(),
      };

  GradebookRow _gradebookRowFromJsonPublic(Map<String, dynamic> j) =>
      GradebookRow(
        studentId: j['studentId'] as String,
        studentName: j['studentName'] as String? ?? '',
        courseTitle: j['courseTitle'] as String? ?? '',
        itemType: j['itemType'] as String? ?? '',
        itemTitle: j['itemTitle'] as String? ?? '',
        grade:
            j['grade'] != null ? (j['grade'] as num).toDouble() : null,
        maxGrade: (j['maxGrade'] as num? ?? 20).toDouble(),
        status: j['status'] as String? ?? 'pending',
        datedAt: j['datedAt'] != null
            ? DateTime.parse(j['datedAt'] as String)
            : null,
      );
}
