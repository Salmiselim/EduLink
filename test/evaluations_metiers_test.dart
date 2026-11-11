import 'package:edulink/features/courses/data/courses_mock_data.dart';
import 'package:edulink/features/evaluations/controllers/evaluations_controller.dart';
import 'package:edulink/features/evaluations/models/evaluations_models.dart';
import 'package:edulink/features/evaluations/repositories/evaluations_repository.dart';
import 'package:edulink/features/evaluations/services/evaluations_api_service.dart';
import 'package:edulink/features/evaluations/services/evaluations_ai_service.dart';
import 'package:edulink/features/evaluations/services/evaluations_local_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Logique métier du module Évaluations, vérifiée avec un repository
/// facture injecté via `EvaluationsController.forTesting` (aucun Firebase,
/// aucune API REST, aucun cache Hive) :
///   - le chargement global reprend TENTATIVES et COPIES (survie au
///     redémarrage de l'application) ;
///   - « Publier » positionne EXPLICITEMENT l'état publié au lieu de le
///     basculer (bug : un quiz publié était sauvegardé en brouillon) ;
///   - le filtre du carnet de notes reconnaît l'IDENTIFIANT de cours
///     (l'ancien code le comparait au titre : filtre inopérant) ;
///   - l'export CSV filtre par identifiant étudiant (l'ancien code comparait
///     le nom) ;
///   - le brouillon IA retombe proprement sur le générateur local sans clé.
void main() {
  late _FakeRepo repo;
  late EvaluationsController controller;

  setUp(() {
    repo = _FakeRepo();
    controller = EvaluationsController.forTesting(repo);
  });

  test(
    'loadAll recharge les tentatives et les copies après redémarrage',
    () async {
      // Côté enseignant : 1 copie en attente de correction sur son devoir.
      controller.currentUserRole = UserRole.teacher;
      controller.currentUserId = 'tch_x';
      repo.submissions = [
        _submission('sub_1', 'assign_x', 'stu_a', SubmissionStatus.submitted),
      ];
      repo.attempts = [
        _attempt('att_1', 'quiz_x', 'stu_a', submitted: true, score: 16),
      ];

      await controller.loadAll();

      expect(controller.attempts.length, 1);
      expect(controller.submissions.length, 1);
      expect(controller.copiesToGrade().length, 1);
      expect(controller.pendingCopiesCount, 1);
    },
  );

  test(
    "Publier depuis l'assistant positionne l'état publié sans le basculer",
    () async {
      controller.currentUserRole = UserRole.teacher;
      controller.currentUserId = 'tch_x';

      // Cas 1 : le corps envoyé porte déjà isPublished = true — l'ancien
      // code appelait ensuite publishQuiz (toggle) → brouillon en base.
      final quizPublished = _quiz('quiz_1', isPublished: true);
      controller.upsertQuiz(quizPublished, publish: true);
      await _drain();

      expect(repo.createdBodies.last['isPublished'], true);
      expect(repo.setPublishedCalls, isEmpty);
      expect(controller.quizById('quiz_1')!.isPublished, true);

      // Cas 2 : la source renvoie un brouillon malgré l'intention de
      // publication — le contrôleur doit positionner explicitement vrai.
      repo.forceCreateAsDraft = true;
      final quizDraft = _quiz('quiz_2', isPublished: true);
      controller.upsertQuiz(quizDraft, publish: true);
      await _drain();

      expect(repo.setPublishedCalls.last, ('quiz_2', true));
      expect(controller.quizById('quiz_2')!.isPublished, true);
    },
  );

  test(
    'Le bouton Publier/Masquer des cartes positionne l\'état demandé',
    () async {
      controller.currentUserRole = UserRole.teacher;
      controller.currentUserId = 'tch_x';
      repo.quizzes = [_quiz('quiz_9', isPublished: true)];
      await controller.loadAll();

      await controller.publishQuizToggle('quiz_9', false);
      expect(repo.setPublishedCalls.last, ('quiz_9', false));
      expect(controller.quizById('quiz_9')!.isPublished, false);

      await controller.publishQuizToggle('quiz_9', true);
      expect(repo.setPublishedCalls.last, ('quiz_9', true));
      expect(controller.quizById('quiz_9')!.isPublished, true);
    },
  );

  test(
    'Le carnet de notes filtre par identifiant de cours et par étudiant',
    () async {
      // Crée un cours réel dans le module Cours pour la résolution
      // identifiant → titre (liaison L4).
      final coursesCtrl = CoursesController.instance;
      coursesCtrl.toggleCurrentUserRole(); // enseignant
      final course = coursesCtrl.createCourse(
        title: 'Cours Carnet de Test',
        subject: 'Algorithmique',
        level: 'L1',
        description: 'Test.',
      );
      coursesCtrl.toggleCurrentUserRole(); // retour étudiant

      controller.gradebookRows = [
        _row(
          studentId: 'stu_amine',
          studentName: 'Étudiant A',
          courseTitle: 'Cours Carnet de Test',
          grade: 15,
        ),
        _row(
          studentId: 'autre_etudiant',
          studentName: 'Étudiant B',
          courseTitle: 'Cours Carnet de Test',
          grade: 8,
        ),
        _row(
          studentId: 'stu_amine',
          studentName: 'Étudiant A',
          courseTitle: 'Un Autre Cours',
          grade: 12,
        ),
      ];

      // Filtre par cours : l'ancien code comparait l'id au titre → vide.
      final filtered = controller.gradebook(courseId: course.id);
      expect(filtered.length, 2);
      expect(
        filtered.every((r) => r.courseTitle == 'Cours Carnet de Test'),
        isTrue,
      );

      // Filtre étudiant + cours combinés.
      final mine = controller.gradebook(
        courseId: course.id,
        student: 'stu_amine',
      );
      expect(mine.length, 1);
      expect(mine.first.grade, 15);

      // Export CSV : même résolution + filtre par IDENTIFIANT étudiant
      // (l'ancien code comparait le nom → CSV étudiant toujours vide).
      final csv = controller.exportGradebookCsv(
        courseId: course.id,
        student: 'stu_amine',
      );
      expect(csv.contains('Cours Carnet de Test'), isTrue);
      expect(csv.contains('Étudiant A'), isTrue);
      expect(csv.contains('Étudiant B'), isFalse);
      final csvAll = controller.exportGradebookCsv();
      expect(csvAll.contains('Étudiant B'), isTrue);

      // Nettoyage de l'état partagé du module Cours.
      coursesCtrl.toggleCurrentUserRole(); // enseignant
      coursesCtrl.deleteCourse(course.id);
      coursesCtrl.toggleCurrentUserRole(); // retour étudiant
    },
  );

  test(
    'Le brouillon IA retombe sur le générateur local sans clé configurée',
    () async {
      // En tests, aucune clé n'est fournie (.env non chargé, pas de
      // --dart-define) : le service est « non configuré ».
      expect(EvaluationsAiService.instance.isConfigured, isFalse);
      final questions = await controller.generateQuizDraftAi(
        topic: 'Chapitre 2 — Récursivité',
      );
      expect(questions, isNotEmpty);
      expect(questions.first.type, QuestionType.qcm);
      expect(questions.first.points, lessThanOrEqualTo(20));
    },
  );

  test(
    'Isolation enseignant : un enseignant ne voit que ses propres quiz, devoirs et documents',
    () async {
      controller.currentUserRole = UserRole.teacher;
      controller.currentUserId = 'tch_alice';

      repo.quizzes = [
        _quiz('quiz_alice', isPublished: true, teacherId: 'tch_alice'),
        _quiz('quiz_bob', isPublished: true, teacherId: 'tch_bob'),
      ];
      repo.assignments = [
        _assignment('asg_alice', teacherId: 'tch_alice', courseId: 'c_alice'),
        _assignment('asg_bob', teacherId: 'tch_bob', courseId: 'c_bob'),
      ];
      repo.documents = [
        _document('doc_alice', teacherId: 'tch_alice', courseId: 'c_alice'),
        _document('doc_bob', teacherId: 'tch_bob', courseId: 'c_bob'),
      ];
      repo.submissions = [
        _submission('sub_alice', 'asg_alice', 'stu_1', SubmissionStatus.submitted),
        _submission('sub_bob', 'asg_bob', 'stu_2', SubmissionStatus.submitted),
      ];

      await controller.loadAll();

      expect(controller.teacherQuizzes.map((q) => q.id), ['quiz_alice']);
      expect(controller.teacherAssignments.map((a) => a.id), ['asg_alice']);
      expect(controller.visibleDocuments().map((d) => d.id), ['doc_alice']);
      expect(controller.copiesToGrade().map((s) => s.id), ['sub_alice']);
    },
  );

  test(
    'Mode étudiant : seuls les quiz, devoirs et documents des cours inscrits sont visibles',
    () async {
      controller.currentUserRole = UserRole.student;
      controller.currentUserId = 'stu_amine';
      controller.enrolledCourseIdsOverride = {'course_algo_1'};

      repo.quizzes = [
        _quiz('q_algo', isPublished: true, courseId: 'course_algo_1'),
        _quiz('q_reseau', isPublished: true, courseId: 'course_reseau_1'),
        _quiz('q_algo_draft', isPublished: false, courseId: 'course_algo_1'),
      ];
      repo.assignments = [
        _assignment('asg_algo', teacherId: 'tch_x', courseId: 'course_algo_1'),
        _assignment('asg_reseau', teacherId: 'tch_y', courseId: 'course_reseau_1'),
      ];
      repo.documents = [
        _document('doc_algo', teacherId: 'tch_x', courseId: 'course_algo_1'),
        _document('doc_reseau', teacherId: 'tch_y', courseId: 'course_reseau_1'),
      ];

      await controller.loadAll();

      expect(controller.studentQuizzes.map((q) => q.id), ['q_algo']);
      expect(controller.publishedQuizzesForStudent().map((q) => q.id), ['q_algo']);
      expect(controller.studentAssignments.map((a) => a.id), ['asg_algo']);
      expect(controller.assignmentsForStudent().map((a) => a.id), ['asg_algo']);
      expect(controller.visibleDocuments().map((d) => d.id), ['doc_algo']);
    },
  );

  test(
    'Suppression enseignant : deleteQuiz, deleteAssignment et deleteDocument suppriment en mémoire et dans le repository',
    () async {
      controller.currentUserRole = UserRole.teacher;
      controller.currentUserId = 'tch_x';

      // Création via upsert (préservation de l'ID client) puis suppression.
      final asg = _assignment('asg_custom_1', teacherId: 'tch_x', courseId: 'course_test');
      final doc = _document('doc_custom_1', teacherId: 'tch_x', courseId: 'course_test');
      final quiz = _quiz('quiz_custom_1', isPublished: false);

      controller.upsertQuiz(quiz);
      controller.upsertAssignment(asg);
      controller.upsertDocument(doc);
      await _drain();

      expect(controller.quizById('quiz_custom_1'), isNotNull);
      expect(controller.assignmentById('asg_custom_1'), isNotNull);
      expect(controller.documentById('doc_custom_1'), isNotNull);

      await controller.deleteQuiz('quiz_custom_1');
      await controller.deleteAssignment('asg_custom_1');
      await controller.deleteDocument('doc_custom_1');

      expect(controller.quizById('quiz_custom_1'), isNull);
      expect(controller.assignmentById('asg_custom_1'), isNull);
      expect(controller.documentById('doc_custom_1'), isNull);
      expect(repo.deletedQuizIds, contains('quiz_custom_1'));
      expect(repo.deletedAssignmentIds, contains('asg_custom_1'));
      expect(repo.deletedDocumentIds, contains('doc_custom_1'));
    },
  );
}

/// Vidange complète des micro-tâches (persistance optimiste du contrôleur).
Future<void> _drain() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Doublures de test
// ═══════════════════════════════════════════════════════════════════════════

class _FakeApi extends EvaluationsApiService {
  _FakeApi() : super(getToken: () async => null);
}

/// Repository facture : données en mémoire simple, enregistrement des
/// intentions d'écriture. Aucun accès à Hive ni au réseau.
class _FakeRepo extends EvaluationsRepository {
  _FakeRepo()
      : super(
          api: _FakeApi(),
          local: EvaluationsLocalService(),
          currentUserId: 'stu_amine',
          currentUserName: 'Amine Ben Ali',
          currentUserRole: UserRole.student,
        );

  List<Quiz> quizzes = [];
  List<Assignment> assignments = [];
  List<CourseDocument> documents = [];
  List<QuizAttempt> attempts = [];
  List<Submission> submissions = [];
  List<GradebookRow> gradebookRows = [];

  final List<String> deletedQuizIds = [];
  final List<String> deletedAssignmentIds = [];
  final List<String> deletedDocumentIds = [];

  /// Corps reçus par createQuiz (vérification du champ isPublished).
  final List<Map<String, dynamic>> createdBodies = [];

  /// Appels à setQuizPublished : paires (quizId, état demandé).
  final List<(String, bool)> setPublishedCalls = [];

  /// Simule une source qui écraserait isPublished à false à la création
  /// (reproduit le comportement buggy d'origine pour valider le correctif).
  bool forceCreateAsDraft = false;

  @override
  Future<List<Quiz>> getQuizzes({String? courseId}) async => quizzes;

  @override
  Future<List<Assignment>> getAssignments({String? courseId}) async =>
      assignments;

  @override
  Future<List<CourseDocument>> getDocuments({String? courseId}) async =>
      documents;

  @override
  Future<List<Map<String, dynamic>>> getUpcoming() async => const [];

  @override
  Future<List<QuizAttempt>> getVisibleAttempts() async => attempts;

  @override
  Future<List<Submission>> getVisibleSubmissions() async => submissions;

  @override
  Future<Quiz> createQuiz(Map<String, dynamic> body) async {
    createdBodies.add(body);
    final rawId = body['id'] as String?;
    final stored = _quizFromBody(
      body,
      id: (rawId != null && rawId.isNotEmpty)
          ? rawId
          : 'quiz_${createdBodies.length}',
      isPublished: forceCreateAsDraft ? false : (body['isPublished'] == true),
    );
    quizzes = [...quizzes, stored];
    return stored;
  }

  @override
  Future<Quiz> updateQuiz(String quizId, Map<String, dynamic> body) async {
    final current = quizzes.firstWhere((q) => q.id == quizId);
    return current;
  }

  @override
  Future<Quiz> getQuiz(String quizId) async =>
      quizzes.firstWhere((q) => q.id == quizId);

  @override
  Future<void> deleteQuiz(String quizId) async {
    deletedQuizIds.add(quizId);
    quizzes = quizzes.where((q) => q.id != quizId).toList();
  }

  @override
  Future<Assignment> createAssignment(Map<String, dynamic> body) async {
    final rawId = (body['id'] as String?) ?? 'asg_new';
    final stored = _assignment(
      rawId,
      teacherId: 'tch_x',
      courseId: (body['courseId'] as String?) ?? 'course_test',
    );
    assignments = [...assignments, stored];
    return stored;
  }

  @override
  Future<void> deleteAssignment(String assignmentId) async {
    deletedAssignmentIds.add(assignmentId);
    assignments = assignments.where((a) => a.id != assignmentId).toList();
  }

  @override
  Future<CourseDocument> createDocument(Map<String, dynamic> body) async {
    final rawId = (body['id'] as String?) ?? 'doc_new';
    final stored = _document(
      rawId,
      teacherId: 'tch_x',
      courseId: (body['courseId'] as String?) ?? 'course_test',
    );
    documents = [...documents, stored];
    return stored;
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    deletedDocumentIds.add(documentId);
    documents = documents.where((d) => d.id != documentId).toList();
  }

  @override
  Future<Quiz> setQuizPublished(
    String quizId, {
    required bool published,
  }) async {
    setPublishedCalls.add((quizId, published));
    final index = quizzes.indexWhere((q) => q.id == quizId);
    final updated = _quiz(quizId, isPublished: published);
    if (index >= 0) {
      quizzes = [...quizzes]..[index] = updated;
    } else {
      quizzes = [...quizzes, updated];
    }
    return updated;
  }

  @override
  Future<List<GradebookRow>> getGradebook(String courseId) async =>
      gradebookRows;
}

Quiz _quiz(
  String id, {
  required bool isPublished,
  String teacherId = 'tch_x',
  String courseId = 'course_test',
}) {
  return Quiz(
    id: id,
    courseId: courseId,
    courseTitle: 'Cours Test',
    teacherId: teacherId,
    teacherName: 'Prof Test',
    title: 'Quiz de test',
    timeLimitMin: 20,
    attemptsAllowed: 2,
    availableFrom: DateTime(2026, 1, 1),
    dueDate: DateTime(2026, 12, 31),
    isPublished: isPublished,
    questions: [
      QuizQuestion(
        id: 'q_0',
        type: QuestionType.qcm,
        text: 'Question de test suffisamment longue ?',
        options: const ['A', 'B', 'C', 'D'],
        correct: const [1],
        points: 2.5,
        explanation: 'Explication de test.',
      ),
    ],
  );
}

Assignment _assignment(
  String id, {
  required String teacherId,
  required String courseId,
}) {
  return Assignment(
    id: id,
    courseId: courseId,
    courseTitle: 'Cours Test',
    teacherId: teacherId,
    teacherName: 'Prof Test',
    title: 'Devoir de test',
    instructions: 'Instructions de test suffisamment détaillées pour valider.',
    attachments: const ['sujet.pdf'],
    dueDate: DateTime(2026, 12, 31),
    maxGrade: 20,
    allowLate: true,
  );
}

CourseDocument _document(
  String id, {
  required String teacherId,
  required String courseId,
}) {
  return CourseDocument(
    id: id,
    courseId: courseId,
    courseTitle: 'Cours Test',
    teacherId: teacherId,
    teacherName: 'Prof Test',
    title: 'Document de test',
    description: 'Description valide du support pédagogique de test.',
    folder: DocumentFolder.polycopies,
    fileUrl: 'poly_test.pdf',
    order: 1,
    visibleFrom: DateTime(2026, 1, 1),
    downloadsCount: 0,
  );
}

Quiz _quizFromBody(Map<String, dynamic> body, {required String id, required bool isPublished}) {
  return Quiz(
    id: id,
    courseId: (body['courseId'] as String?) ?? 'course_test',
    courseTitle: '',
    teacherId: 'tch_x',
    teacherName: 'Prof Test',
    title: (body['title'] as String?) ?? 'Quiz',
    timeLimitMin: (body['timeLimitMin'] as num?)?.toInt() ?? 20,
    attemptsAllowed: (body['attemptsAllowed'] as num?)?.toInt() ?? 1,
    availableFrom: DateTime.tryParse((body['availableFrom'] as String?) ?? '') ??
        DateTime(2026, 1, 1),
    dueDate: DateTime.tryParse((body['dueDate'] as String?) ?? '') ??
        DateTime(2026, 12, 31),
    isPublished: isPublished,
    questions: const [],
  );
}

QuizAttempt _attempt(
  String id,
  String quizId,
  String studentId, {
  required bool submitted,
  required double score,
}) {
  return QuizAttempt(
    id: id,
    quizId: quizId,
    studentId: studentId,
    studentName: 'Étudiant Test',
    attemptNo: 1,
    answers: const [[1]],
    score: submitted ? score : null,
    startedAt: DateTime(2026),
    submittedAt: submitted ? DateTime(2026) : null,
  );
}

Submission _submission(
  String id,
  String assignmentId,
  String studentId,
  SubmissionStatus status,
) {
  return Submission(
    id: id,
    assignmentId: assignmentId,
    studentId: studentId,
    studentName: 'Étudiant Test',
    fileUrls: const ['rendu_1.pdf'],
    comment: 'Commentaire de test suffisant.',
    submittedAt: DateTime(2026),
    isLate: false,
    status: status,
  );
}

GradebookRow _row({
  required String studentId,
  required String studentName,
  required String courseTitle,
  required double grade,
}) {
  return GradebookRow(
    studentId: studentId,
    studentName: studentName,
    courseTitle: courseTitle,
    itemType: 'quiz',
    itemTitle: 'Quiz 1',
    grade: grade,
    maxGrade: 20,
    status: 'graded',
    datedAt: DateTime(2026),
  );
}
