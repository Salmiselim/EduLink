import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../courses/data/courses_mock_data.dart';
import '../models/evaluations_models.dart';
import '../services/evaluations_ai_service.dart';
import '../services/evaluations_api_service.dart';
import '../services/evaluations_firestore_service.dart';
import '../services/evaluations_local_service.dart';
import '../repositories/evaluations_repository.dart';

/// Contrôleur d'état réactif du module Évaluations.
///
/// Remplace l'ancien [EvaluationsController] basé sur des données mock.
/// Délègue toute la logique métier et réseau au [EvaluationsRepository].
///
/// Expose via [ChangeNotifier] :
///   - Les listes chargées ([quizzes], [assignments], [documents], etc.)
///   - L'état de chargement ([isLoading]) et les erreurs ([error])
///   - Les méthodes CRUD et métier (quiz, dépôts, documents)
///
/// En mode [kDebugMode] et si le backend est inaccessible, le contrôleur
/// charge des données mock depuis [EvaluationsMockFallback] pour permettre
/// le développement sans serveur.
class EvaluationsController extends ChangeNotifier {
  // ── Singleton ─────────────────────────────────────────────────────────────

  static EvaluationsController? _instance;

  /// Singleton partagé par tous les écrans.
  /// Initialiser via [EvaluationsController.init] au démarrage de l'app.
  static EvaluationsController get instance {
    _instance ??= EvaluationsController._();
    return _instance!;
  }

  EvaluationsController._() : _isTesting = false {
    _initFuture = _initRepository();
    CoursesController.instance.addListener(_onCoursesUpdated);
  }

  /// Constructeur réservé aux tests : injecte directement un repository
  /// (double de service) sans toucher à Firebase, à l'API REST ni au cache
  /// Hive — permet de vérifier la logique métier de façon déterministe.
  @visibleForTesting
  EvaluationsController.forTesting(EvaluationsRepository repo)
      : _isTesting = true {
    _repo = repo;
    _ready = true;
  }

  // ── Repository & services ─────────────────────────────────────────────────

  late EvaluationsRepository _repo;
  bool _ready = false;
  bool _cloudReady = false;
  final bool _isTesting;
  Future<void>? _initFuture;
  String _lastCourseIdsSignature = '';

  /// Vrai si aucun compte Firebase réel n'est connecté (mode démonstration).
  bool get isDemoMode => !_cloudReady;

  Future<void> _initRepository() async {
    final local = EvaluationsLocalService();
    // Source de données : Firestore quand Firebase est initialisé, sinon
    // l'ancien client REST. Les deux implémentations partagent la même
    // surface d'appels (voir EvaluationsFirestoreService).
    final EvaluationsApiService api = Firebase.apps.isNotEmpty
        ? EvaluationsFirestoreService()
        : EvaluationsApiService(
            getToken: () async => null,
          );
    _repo = EvaluationsRepository(
      api: api,
      local: local,
      currentUserId: currentUserId,
      currentUserName: currentUserName,
      currentUserRole: currentUserRole,
    );
    await _repo.init();
    _ready = true;
    // Charge les données initiales pour la vue courante.
    await loadAll();
  }

  /// Synchronise la liste des cours liés dès que le module Cours change
  /// (ex: inscription d'un étudiant à un cours ou création d'un cours par
  /// l'enseignant) et recharge les évaluations si les cours ont évolué.
  void _onCoursesUpdated() {
    if (_isTesting) return;
    _syncCoursesFromModule();
    final currentSig = _courses.map((c) => c.id).join(',');
    if (currentSig != _lastCourseIdsSignature) {
      _lastCourseIdsSignature = currentSig;
      if (_ready) {
        loadAll();
      } else {
        notifyListeners();
      }
    } else {
      notifyListeners();
    }
  }

  /// Met à jour `_courses` selon le rôle :
  /// - Enseignant : uniquement les cours dont il est propriétaire (`teacherCourses`).
  /// - Étudiant : uniquement les cours auxquels il est inscrit (`enrolledCourses`).
  void _syncCoursesFromModule() {
    final coursesCtrl = CoursesController.instance;
    final source = isTeacher
        ? coursesCtrl.teacherCourses
        : coursesCtrl.enrolledCourses;
    if (source.isNotEmpty || _cloudReady) {
      _courses = source
          .map((c) => LinkedCourse(
                id: c.id,
                title: c.title,
                subject: c.subject,
                level: c.level,
                teacherId: c.teacherId,
                teacherName: c.teacherName,
              ))
          .toList();
    }
  }

  // ── État utilisateur ──────────────────────────────────────────────────────

  /// IDs utilisateur disponibles pour le basculement de rôle en dev.
  static const String _defaultStudentId = 'stu_amine';
  static const String _defaultTeacherId = 'tch_leila';

  UserRole currentUserRole = UserRole.student;
  String currentUserId = _defaultStudentId;
  String currentUserName = 'Amine Ben Ali';

  /// Bascule entre rôle étudiant et enseignant (mode démonstration uniquement).
  void toggleRole() {
    if (_cloudReady) {
      notifyListeners();
      return;
    }
    if (currentUserRole == UserRole.student) {
      currentUserRole = UserRole.teacher;
      currentUserId = _defaultTeacherId;
      currentUserName = 'Dr. Leila Mansour';
    } else {
      currentUserRole = UserRole.student;
      currentUserId = _defaultStudentId;
      currentUserName = 'Amine Ben Ali';
    }
    if (_ready) {
      _repo.currentUserId = currentUserId;
      _repo.currentUserName = currentUserName;
      _repo.currentUserRole = currentUserRole;
      if (_repo.api is EvaluationsFirestoreService) {
        (_repo.api as EvaluationsFirestoreService).setRole(currentUserRole == UserRole.teacher ? 'teacher' : 'student');
      }
    }
    loadAll();
    notifyListeners();
  }

  /// Vide toutes les données en mémoire et le cache local lors d'une
  /// déconnexion ou d'un changement d'utilisateur pour empêcher toute fuite
  /// de données entre comptes.
  Future<void> resetSession() async {
    quizzes = [];
    attempts = [];
    assignments = [];
    submissions = [];
    documents = [];
    gradebookRows = [];
    upcomingItems = [];
    notifications = [];
    selectedCourseId = null;
    error = null;
    _cloudReady = false;
    _lastCourseIdsSignature = '';
    currentUserRole = UserRole.student;
    currentUserId = _defaultStudentId;
    currentUserName = 'Amine Ben Ali';
    if (_ready) {
      _repo.currentUserId = currentUserId;
      _repo.currentUserName = currentUserName;
      _repo.currentUserRole = currentUserRole;
      await _repo.clearLocalCache();
    }
    notifyListeners();
  }

  /// Connecte le contrôleur au compte Firebase : identité réelle (uid, nom,
  /// rôle lu dans `users/{uid}`), liaison L4 avec les cours du module Cours
  /// (mêmes identifiants), puis rechargement des données depuis Firestore.
  Future<void> connectCloud() async {
    if (!_ready && _initFuture != null) {
      try {
        await _initFuture;
      } catch (_) {}
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      // Si l'utilisateur connecté change, purge immédiatement l'état précédent
      // et le cache Hive afin qu'aucune donnée d'un autre compte ne subsiste.
      if (currentUserId != user.uid) {
        quizzes = [];
        attempts = [];
        assignments = [];
        submissions = [];
        documents = [];
        gradebookRows = [];
        upcomingItems = [];
        notifications = [];
        selectedCourseId = null;
        if (_ready) {
          await _repo.clearLocalCache();
        }
      }
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      currentUserId = user.uid;
      currentUserName = (userDoc.data()?['name'] as String?) ??
          user.displayName ??
          'Utilisateur EduLink';
      currentUserRole = (userDoc.data()?['role'] == 'teacher')
          ? UserRole.teacher
          : UserRole.student;
      _cloudReady = true;
      if (_ready) {
        _repo.currentUserId = currentUserId;
        _repo.currentUserName = currentUserName;
        _repo.currentUserRole = currentUserRole;
      }
      // Liaison L4 réelle : cours possédés (enseignant) ou cours inscrits (étudiant).
      _syncCoursesFromModule();
      _lastCourseIdsSignature = _courses.map((c) => c.id).join(',');
      if (_ready) await loadAll();
      notifyListeners();
    } catch (e) {
      debugPrint('[EvalCloud] connectCloud : $e');
    }
  }

  // ── État de chargement ────────────────────────────────────────────────────

  bool isLoading = false;
  String? error;

  /// Données chargées depuis le repository (API ou cache Hive).
  List<Quiz> quizzes = [];
  List<QuizAttempt> attempts = [];
  List<Assignment> assignments = [];
  List<Submission> submissions = [];
  List<CourseDocument> documents = [];
  List<GradebookRow> gradebookRows = [];
  List<Map<String, dynamic>> upcomingItems = [];
  List<EvalNotification> notifications = [];

  // ── Cours liés (L4 : filtre par courseId) ─────────────────────────────────

  /// Cours sélectionné pour filtrer quiz, devoirs et documents.
  /// null = tous les cours de l'utilisateur.
  String? selectedCourseId;

  // ════════════════════════════════════════════════════════════════════════
  // CHARGEMENT GLOBAL
  // ════════════════════════════════════════════════════════════════════════

  /// Charge toutes les données du module selon le rôle et le cours courant.
  /// Inclut désormais les TENTATIVES, les COPIES et le CARNET DE NOTES :
  /// sans ce chargement, après un redémarrage de l'application, le compteur
  /// de tentatives (`canTakeQuiz`), la liste « Copies à corriger » et le
  /// carnet restaient vides alors que les données existaient dans Firestore.
  Future<void> loadAll() async {
    if (!_ready && _initFuture != null) {
      try {
        await _initFuture;
      } catch (_) {}
    }
    if (!_ready) return;
    if (!_isTesting) {
      _syncCoursesFromModule();
    }
    _setLoading(true);
    try {
      await Future.wait([
        _loadQuizzes(),
        _loadAssignments(),
        _loadDocuments(),
        _loadUpcoming(),
        _loadAttempts(),
        _loadSubmissions(),
        _loadGradebooks(),
      ]);
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadQuizzes() async {
    quizzes = await _repo.getQuizzes(courseId: selectedCourseId);
  }

  Future<void> _loadAssignments() async {
    assignments = await _repo.getAssignments(courseId: selectedCourseId);
  }

  Future<void> _loadDocuments() async {
    documents = await _repo.getDocuments(courseId: selectedCourseId);
  }

  Future<void> _loadUpcoming() async {
    upcomingItems = await _repo.getUpcoming();
  }

  /// Tentatives visibles : celles de l'étudiant, ou celles des quiz de
  /// l'enseignant (alimente `canTakeQuiz`, les résultats et les statistiques).
  Future<void> _loadAttempts() async {
    attempts = await _repo.getVisibleAttempts();
  }

  /// Copies visibles : celles de l'étudiant, ou celles des devoirs de
  /// l'enseignant (alimente « Copies à corriger » et `canSubmitAssignment`).
  Future<void> _loadSubmissions() async {
    submissions = await _repo.getVisibleSubmissions();
  }

  /// Carnet de notes agrégé sur les cours PERTINENTS pour l'utilisateur :
  /// les cours dont il est propriétaire (enseignant) ou ceux où il est
  /// inscrit (étudiant) — évite de balayer tout le catalogue.
  Future<void> _loadGradebooks() async {
    final coursesCtrl = CoursesController.instance;
    final courseIds = isTeacher
        ? coursesCtrl.teacherCourses.map((c) => c.id).toSet()
        : coursesCtrl.myEnrollments.map((e) => e.courseId).toSet();
    final rows = <GradebookRow>[];
    for (final id in courseIds) {
      try {
        rows.addAll(await _repo.getGradebook(id));
      } catch (_) {
        // Un cours sans notes (ou hors-ligne) ne doit pas bloquer les autres.
      }
    }
    gradebookRows = rows;
  }

  // ════════════════════════════════════════════════════════════════════════
  // QUIZ — CRUD
  // ════════════════════════════════════════════════════════════════════════

  Future<Quiz?> createQuiz(Map<String, dynamic> body) async {
    return _wrap(() async {
      final quiz = await _repo.createQuiz(body);
      quizzes = [...quizzes, quiz];
      notifyListeners();
      return quiz;
    });
  }

  Future<Quiz?> updateQuiz(String quizId, Map<String, dynamic> body) async {
    return _wrap(() async {
      final updated = await _repo.updateQuiz(quizId, body);
      quizzes = quizzes.map((q) => q.id == quizId ? updated : q).toList();
      notifyListeners();
      return updated;
    });
  }

  Future<void> deleteQuiz(String quizId) async {
    final prevQuizzes = quizzes;
    final prevAttempts = attempts;
    quizzes = quizzes.where((q) => q.id != quizId).toList();
    attempts = attempts.where((a) => a.quizId != quizId).toList();
    notifyListeners();
    await _wrapVoid(() async {
      try {
        await _repo.deleteQuiz(quizId);
      } catch (e) {
        quizzes = prevQuizzes;
        attempts = prevAttempts;
        notifyListeners();
        rethrow;
      }
    });
  }

  Future<Quiz?> publishQuiz(String quizId) async {
    return _wrap(() async {
      final published = await _repo.publishQuiz(quizId);
      quizzes = quizzes.map((q) => q.id == quizId ? published : q).toList();
      _addNotification(
        title: 'Quiz publié',
        body: 'Le quiz "${published.title}" est maintenant visible.',
      );
      notifyListeners();
      return published;
    });
  }

  Future<List<Map<String, dynamic>>?> generateQuizDraft({
    required String chapterText,
    required int questionCount,
  }) async {
    return _wrap(() => _repo.generateQuizDraft(
          chapterText: chapterText,
          questionCount: questionCount,
        ));
  }

  // ── Tentatives ────────────────────────────────────────────────────────────

  Future<QuizAttempt?> startAttempt(String quizId) async {
    return _wrap(() => _repo.startAttempt(quizId));
  }

  /// Sauvegarde locale des réponses intermédiaires (crash recovery).
  Future<void> saveDraftAnswers({
    required String attemptId,
    required List<List<int>> answers,
  }) =>
      _repo.saveDraftAnswers(attemptId: attemptId, answers: answers);

  List<List<int>>? getDraftAnswers(String attemptId) =>
      _repo.getDraftAnswers(attemptId);

  Future<QuizAttempt?> submitAttempt(
    String attemptId,
    List<List<int>> answers,
  ) async {
    return _wrap(() async {
      final attempt = await _repo.submitAttempt(attemptId, answers);
      attempts = [
        ...attempts.where((a) => a.id != attempt.id),
        attempt,
      ];
      await _loadGradebooks();
      notifyListeners();
      return attempt;
    });
  }

  Future<Map<String, dynamic>?> getQuizResults(String quizId) =>
      _repo.getQuizResults(quizId);

  // ════════════════════════════════════════════════════════════════════════
  // ASSIGNMENTS — CRUD
  // ════════════════════════════════════════════════════════════════════════

  Future<Assignment?> createAssignment(Map<String, dynamic> body) async {
    return _wrap(() async {
      final a = await _repo.createAssignment(body);
      assignments = [...assignments, a];
      _addNotification(
        title: 'Devoir créé',
        body: '"${a.title}" — échéance ${a.dueDate.toLocal()}.',
      );
      notifyListeners();
      return a;
    });
  }

  Future<Assignment?> updateAssignment(
    String assignmentId,
    Map<String, dynamic> body,
  ) async {
    return _wrap(() async {
      final updated = await _repo.updateAssignment(assignmentId, body);
      assignments = assignments
          .map((a) => a.id == assignmentId ? updated : a)
          .toList();
      notifyListeners();
      return updated;
    });
  }

  Future<void> deleteAssignment(String assignmentId) async {
    final prevAssignments = assignments;
    final prevSubmissions = submissions;
    assignments = assignments.where((a) => a.id != assignmentId).toList();
    submissions =
        submissions.where((s) => s.assignmentId != assignmentId).toList();
    notifyListeners();
    await _wrapVoid(() async {
      try {
        await _repo.deleteAssignment(assignmentId);
      } catch (e) {
        assignments = prevAssignments;
        submissions = prevSubmissions;
        notifyListeners();
        rethrow;
      }
    });
  }

  // ── Submissions ───────────────────────────────────────────────────────────

  Future<Submission?> submitAssignment({
    required String assignmentId,
    required List<String> fileUrls,
    required String comment,
  }) async {
    return _wrap(() async {
      final sub = await _repo.submitAssignment(
        assignmentId: assignmentId,
        fileUrls: fileUrls,
        comment: comment,
      );
      submissions = [
        ...submissions.where((s) =>
            !(s.assignmentId == assignmentId && s.studentId == sub.studentId)),
        sub,
      ];
      await _loadGradebooks();
      notifyListeners();
      return sub;
    });
  }

  Future<List<Submission>?> getSubmissions(String assignmentId) =>
      _repo.getSubmissions(assignmentId);

  Future<Submission?> getSubmission(String submissionId) =>
      _repo.getSubmission(submissionId);

  Future<Submission?> gradeSubmission({
    required String submissionId,
    required double grade,
    required String feedback,
  }) async {
    return _wrap(() async {
      final graded = await _repo.gradeSubmission(
        submissionId: submissionId,
        grade: grade,
        feedback: feedback,
      );
      submissions = submissions
          .map((s) => s.id == submissionId ? graded : s)
          .toList();
      await _loadGradebooks();
      notifyListeners();
      return graded;
    });
  }

  // ════════════════════════════════════════════════════════════════════════
  // DOCUMENTS — CRUD
  // ════════════════════════════════════════════════════════════════════════

  Future<CourseDocument?> createDocument(Map<String, dynamic> body) async {
    return _wrap(() async {
      final doc = await _repo.createDocument(body);
      documents = [...documents, doc];
      notifyListeners();
      return doc;
    });
  }

  Future<CourseDocument?> updateDocument(
    String documentId,
    Map<String, dynamic> body,
  ) async {
    return _wrap(() async {
      final updated = await _repo.updateDocument(documentId, body);
      documents = documents
          .map((d) => d.id == documentId ? updated : d)
          .toList();
      notifyListeners();
      return updated;
    });
  }

  Future<void> deleteDocument(String documentId) async {
    final prevDocuments = documents;
    documents = documents.where((d) => d.id != documentId).toList();
    notifyListeners();
    await _wrapVoid(() async {
      try {
        await _repo.deleteDocument(documentId);
      } catch (e) {
        documents = prevDocuments;
        notifyListeners();
        rethrow;
      }
    });
  }

  // ════════════════════════════════════════════════════════════════════════
  // GRADEBOOK
  // ════════════════════════════════════════════════════════════════════════

  Future<void> loadGradebook(String courseId) async {
    _setLoading(true);
    try {
      gradebookRows = await _repo.getGradebook(courseId);
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // HELPERS MÉTIER (compatibilité avec les écrans existants)
  // ════════════════════════════════════════════════════════════════════════

  /// Permet de surcharger explicitement la liste des cours inscrits en test.
  @visibleForTesting
  Set<String>? enrolledCourseIdsOverride;

  /// Identifiants des cours auxquels l'étudiant courant est inscrit.
  Set<String>? get _enrolledCourseIds {
    if (enrolledCourseIdsOverride != null) return enrolledCourseIdsOverride;
    if (_isTesting) return null;
    return CoursesController.instance.myEnrollments
        .map((e) => e.courseId)
        .toSet();
  }

  /// Quiz appartenant exclusivement à l'enseignant connecté.
  List<Quiz> get teacherQuizzes =>
      quizzes.where((q) => q.teacherId == currentUserId).toList();

  /// Devoirs appartenant exclusivement à l'enseignant connecté.
  List<Assignment> get teacherAssignments =>
      assignments.where((a) => a.teacherId == currentUserId).toList();

  /// Quiz visibles par l'étudiant courant : publiés et dans ses cours inscrits.
  List<Quiz> get studentQuizzes {
    final enrolled = _enrolledCourseIds;
    return quizzes.where((q) {
      if (!q.isPublished) return false;
      if (enrolled != null && !enrolled.contains(q.courseId)) return false;
      return true;
    }).toList();
  }

  /// Devoirs visibles par l'étudiant courant : uniquement ceux des cours
  /// auxquels il est inscrit.
  List<Assignment> get studentAssignments {
    final enrolled = _enrolledCourseIds;
    if (enrolled == null) return assignments;
    return assignments.where((a) => enrolled.contains(a.courseId)).toList();
  }

  /// Nombre de quiz à faire (pas encore de tentative soumise).
  int get studentPendingTodoCount {
    final doneIds = attempts
        .where((a) => a.isSubmitted)
        .map((a) => a.quizId)
        .toSet();
    return studentQuizzes.where((q) => !doneIds.contains(q.id)).length;
  }

  /// Nombre de copies en attente de correction pour l'enseignant.
  int get pendingCopiesCount => copiesToGrade().length;

  /// Moyenne calculée localement à partir du carnet de notes chargé.
  double calculateStudentAverage() {
    final graded = gradebookRows.where((r) => r.grade != null).toList();
    if (graded.isEmpty) return 0;
    final sum = graded.fold<double>(
      0,
      (acc, r) => acc + (r.grade! / r.maxGrade * 20),
    );
    return sum / graded.length;
  }

  /// Nombre d'évaluations déjà complétées par l'étudiant.
  int get studentCompletedCount => gradebookRows
      .where((r) => r.grade != null && r.studentId == currentUserId)
      .length;

  // ════════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS INTERNES
  // ════════════════════════════════════════════════════════════════════════

  void _addNotification({required String title, required String body}) {
    notifications.insert(
      0,
      EvalNotification(title: title, body: body, createdAt: DateTime.now()),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // UTILITAIRES STATIQUES (compatibilité avec les appels EvaluationsController.xxx)
  // ════════════════════════════════════════════════════════════════════════

  /// Formate un score numérique : entier si pas de décimale, sinon 1 chiffre.
  static String formatScore(double score) {
    return score == score.roundToDouble()
        ? score.toInt().toString()
        : score.toStringAsFixed(1);
  }

  /// Génère le CSV du carnet de notes chargé. Même correctif que
  /// [gradebook] : résolution identifiant de cours → titre.
  String exportGradebookCsv({String? courseId, String? student}) {
    String? courseTitle;
    if (courseId != null) {
      courseTitle = _courseTitleFor(courseId) ?? courseId;
    }
    final rows = gradebookRows.where((r) {
      if (courseTitle != null && r.courseTitle != courseTitle) return false;
      // Même convention que [gradebook] : filtre par IDENTIFIANT étudiant
      // (l'écran passe currentUserId, pas le nom).
      if (student != null && r.studentId != student) return false;
      return true;
    }).toList();
    final buf = StringBuffer(
      'Cours;Etudiant;Type;Titre;Note;NoteMax;Statut;Date\n',
    );
    for (final r in rows) {
      buf.writeln(
        '${_csv(r.courseTitle)};${_csv(r.studentName)};${_csv(r.itemType)};'
        '${_csv(r.itemTitle)};${r.grade?.toString() ?? ''};${r.maxGrade};'
        '${_csv(r.status)};${r.datedAt?.toIso8601String() ?? ''}',
      );
    }
    return buf.toString();
  }

  String _csv(String v) => '"${v.replaceAll('"', '""')}"';

  // ════════════════════════════════════════════════════════════════════════
  // WRAPPERS DE COMPATIBILITÉ (API synchrone conservée pour les écrans existants)
  // ════════════════════════════════════════════════════════════════════════

  /// Vrai si l'utilisateur courant est un enseignant.
  bool get isTeacher => currentUserRole == UserRole.teacher;

  /// Liste brute des cours accessibles (utilisée dans les wizards enseignant).
  /// En attendant le chargement API, retourne une liste locale statique de démo.
  List<LinkedCourse> get courses => _courses;
  List<LinkedCourse> _courses = const [
    LinkedCourse(
      id: 'course_algo_1',
      title: 'Algorithmique',
      subject: 'Algorithmique',
      level: 'L2',
      teacherId: 'tch_leila',
      teacherName: 'Dr. Leila Mansour',
    ),
    LinkedCourse(
      id: 'course_bdd_1',
      title: 'Bases de Données',
      subject: 'Bases de Données',
      level: 'L2',
      teacherId: 'tch_leila',
      teacherName: 'Dr. Leila Mansour',
    ),
    LinkedCourse(
      id: 'course_reseau_1',
      title: 'Réseaux & Sécurité',
      subject: 'Réseaux & Sécurité',
      level: 'L3',
      teacherId: 'tch_leila',
      teacherName: 'Dr. Leila Mansour',
    ),
  ];

  /// Cours auxquels l'étudiant est inscrit / que l'enseignant possède.
  List<LinkedCourse> get accessibleCourses => courses;

  /// Quiz publiés visibles par l'étudiant courant (filtrés par cours inscrits).
  List<Quiz> publishedQuizzesForStudent() => studentQuizzes;

  /// Devoirs accessibles à l'étudiant courant (filtrés par cours inscrits).
  List<Assignment> assignmentsForStudent() => studentAssignments;

  /// Nombre de tentatives soumises pour un quiz donné par un étudiant.
  int attemptCountFor(String quizId, String studentId) => attempts
      .where((a) => a.quizId == quizId && a.studentId == studentId && a.isSubmitted)
      .length;

  /// Tentatives d'un quiz filtrées par étudiant (optionnel), du plus récent au plus ancien.
  List<QuizAttempt> attemptsForQuiz(String quizId, {String? student}) {
    return attempts
        .where((a) =>
            a.quizId == quizId &&
            (student == null || a.studentId == student))
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  /// Trouve une tentative par son identifiant.
  QuizAttempt? attemptById(String id) =>
      attempts.where((a) => a.id == id).isNotEmpty
          ? attempts.firstWhere((a) => a.id == id)
          : null;

  /// Vrai si l'étudiant peut encore passer le quiz (tentatives restantes + fenêtre ouverte).
  bool canTakeQuiz(Quiz quiz) {
    final now = DateTime.now();
    if (now.isBefore(quiz.availableFrom) || now.isAfter(quiz.dueDate)) {
      return false;
    }
    final used = attemptCountFor(quiz.id, currentUserId);
    return used < quiz.attemptsAllowed;
  }

  /// Trouve la copie déposée par un étudiant pour un devoir donné (null si aucune).
  Submission? submissionFor(String assignmentId, String studentId) {
    final matching = submissions.where(
      (s) => s.assignmentId == assignmentId && s.studentId == studentId,
    );
    return matching.isNotEmpty ? matching.first : null;
  }

  /// Vrai si l'étudiant peut encore déposer une copie (pas encore déposée, ou retard autorisé).
  bool canSubmitAssignment(Assignment assignment) {
    final existing = submissionFor(assignment.id, currentUserId);
    if (existing != null) return false;
    if (DateTime.now().isAfter(assignment.dueDate) && !assignment.allowLate) {
      return false;
    }
    return true;
  }

  /// Retourne une liste des copies en attente de correction pour l'enseignant.
  List<Submission> copiesToGrade() {
    final myAssignIds = teacherAssignments.map((a) => a.id).toSet();
    return submissions.where((s) {
      if (s.status != SubmissionStatus.submitted) return false;
      if (myAssignIds.isNotEmpty && !myAssignIds.contains(s.assignmentId)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Trouve un quiz par son identifiant.
  Quiz? quizById(String id) {
    final found = quizzes.where((q) => q.id == id);
    return found.isNotEmpty ? found.first : null;
  }

  /// Trouve un devoir par son identifiant.
  Assignment? assignmentById(String id) {
    final found = assignments.where((a) => a.id == id);
    return found.isNotEmpty ? found.first : null;
  }

  /// Trouve une copie par son identifiant.
  Submission? submissionById(String id) {
    final found = submissions.where((s) => s.id == id);
    return found.isNotEmpty ? found.first : null;
  }

  /// Trouve un document par son identifiant.
  CourseDocument? documentById(String id) {
    final found = documents.where((d) => d.id == id);
    return found.isNotEmpty ? found.first : null;
  }

  /// Résout le TITRE d'un cours à partir de son identifiant (les lignes du
  /// carnet ne portent que le titre). Cherche d'abord dans les cours liés du
  /// contrôleur, puis dans le module Cours (liaison L4).
  String? _courseTitleFor(String courseId) {
    for (final c in _courses) {
      if (c.id == courseId) return c.title;
    }
    for (final c in CoursesController.instance.allCourses) {
      if (c.id == courseId) return c.title;
    }
    return null;
  }

  /// Lignes du carnet de notes filtrées localement (pour l'écran Carnet).
  /// Lignes du carnet de notes filtrées localement (pour l'écran Carnet).
  /// Correctif : le filtre recevait un IDENTIFIANT de cours et le comparait
  /// au TITRE stocké dans la ligne — aucun résultat n'apparaissait dès
  /// qu'un cours était sélectionné.
  /// Si `gradebookRows` est vide (hors-ligne, démonstration), consolide en
  /// temps réel avec les quiz complétés et devoirs notés en mémoire.
  List<GradebookRow> gradebook({String? courseId, String? student}) {
    String? courseTitle;
    if (courseId != null) {
      courseTitle = _courseTitleFor(courseId) ?? courseId;
    }
    // Si des lignes sont déjà synchronisées du serveur, on les filtre
    if (gradebookRows.isNotEmpty) {
      return gradebookRows.where((r) {
        if (courseTitle != null && r.courseTitle != courseTitle) return false;
        if (student != null && r.studentId != student) return false;
        return true;
      }).toList();
    }

    // Sinon, synthèse dynamique immédiate à partir des objets en mémoire
    final synthesized = <GradebookRow>[];
    for (final q in quizzes) {
      if (courseId != null && q.courseId != courseId) continue;
      final atts = attempts.where((a) => a.quizId == q.id && a.isSubmitted).toList();
      for (final a in atts) {
        if (student != null && a.studentId != student) continue;
        synthesized.add(GradebookRow(
          studentId: a.studentId,
          studentName: a.studentName.isNotEmpty ? a.studentName : 'Étudiant',
          courseTitle: q.courseTitle,
          itemType: 'Quiz',
          itemTitle: q.title,
          grade: a.score,
          maxGrade: 20,
          status: 'Noté',
          datedAt: a.submittedAt,
        ));
      }
    }

    for (final asg in assignments) {
      if (courseId != null && asg.courseId != courseId) continue;
      final subs = submissions.where((s) => s.assignmentId == asg.id).toList();
      for (final s in subs) {
        if (student != null && s.studentId != student) continue;
        synthesized.add(GradebookRow(
          studentId: s.studentId,
          studentName: s.studentName.isNotEmpty ? s.studentName : 'Étudiant',
          courseTitle: asg.courseTitle,
          itemType: 'Devoir',
          itemTitle: asg.title,
          grade: s.grade,
          maxGrade: asg.maxGrade,
          status: s.status == SubmissionStatus.graded ? 'Noté' : 'En attente',
          datedAt: s.submittedAt,
        ));
      }
    }

    return synthesized;
  }

  /// Documents visibles filtrés par propriétaire (enseignant) ou cours inscrits
  /// (étudiant), cours sélectionné, dossier et recherche textuelle.
  List<CourseDocument> visibleDocuments({
    String? courseId,
    DocumentFolder? folder,
    String? search,
  }) {
    final now = DateTime.now();
    final enrolled = isTeacher ? null : _enrolledCourseIds;
    return documents.where((d) {
      if (isTeacher && d.teacherId.isNotEmpty && d.teacherId != currentUserId) {
        return false;
      }
      if (!isTeacher && enrolled != null && !enrolled.contains(d.courseId)) {
        return false;
      }
      if (courseId != null && d.courseId != courseId) return false;
      if (folder != null && d.folder != folder) return false;
      if (!isTeacher && d.visibleFrom.isAfter(now)) return false;
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        if (!d.title.toLowerCase().contains(q) &&
            !d.description.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  // ── Wrappers synchrones d'écriture (optimiste) ───────────────────────────

  /// Crée ou met à jour un quiz. Déclenche l'API en arrière-plan.
  /// [publish] à true → positionne explicitement l'état publié APRÈS
  /// l'enregistrement. Correctif important : l'ancien code appelait
  /// `publishQuiz` qui BASCULE l'état — un quiz créé avec
  /// `isPublished: true` était donc re-basculé en brouillon dans Firestore
  /// alors que l'interface affichait « Publié ».
  void upsertQuiz(Quiz quiz, {bool publish = false}) {
    // Mise à jour optimiste locale.
    final idx = quizzes.indexWhere((q) => q.id == quiz.id);
    if (idx >= 0) {
      quizzes = [...quizzes]..[idx] = quiz;
    } else {
      quizzes = [...quizzes, quiz];
    }
    notifyListeners();
    // Persistance en arrière-plan : enregistrement puis positionnement
    // EXPLICITE de l'état publié si demandé (corrige le bug du toggle),
    // rafraîchissement final avec l'état réel renvoyé par la source.
    final body = _quizToBody(quiz);
    Future<void> persist() async {
      Quiz stored;
      if (idx >= 0) {
        stored = await _repo.updateQuiz(quiz.id, body);
        quizzes = quizzes
            .map((q) => q.id == stored.id ? stored : q)
            .toList();
      } else {
        stored = await _repo.createQuiz(body);
        quizzes = [...quizzes.where((q) => q.id != quiz.id), stored];
      }
      if (publish && !stored.isPublished) {
        stored = await _repo.setQuizPublished(stored.id, published: true);
        quizzes = quizzes
            .map((q) => q.id == stored.id ? stored : q)
            .toList();
      }
      notifyListeners();
    }

    persist()
        .catchError((e) => debugPrint('[Controller] upsertQuiz error: $e'));
  }

  /// Publie ou masque un quiz : positionne EXPLICITEMENT l'état demandé
  /// ([publish]) au lieu de basculer — la carte enseignant appelle cette
  /// méthode avec `!quiz.isPublished` comme cible.
  Future<Quiz?> publishQuizToggle(String quizId, [bool publish = true]) {
    return _wrap(() async {
      final updated = await _repo.setQuizPublished(quizId, published: publish);
      quizzes = quizzes.map((q) => q.id == quizId ? updated : q).toList();
      if (publish) {
        _addNotification(
          title: 'Quiz publié',
          body: 'Le quiz "${updated.title}" est maintenant visible.',
        );
      }
      notifyListeners();
      return updated;
    });
  }

  /// Crée ou met à jour un devoir. Déclenche l'API en arrière-plan.
  void upsertAssignment(Assignment assignment) {
    final idx = assignments.indexWhere((a) => a.id == assignment.id);
    if (idx >= 0) {
      assignments = [...assignments]..[idx] = assignment;
    } else {
      assignments = [...assignments, assignment];
    }
    notifyListeners();
    final body = _assignmentToBody(assignment);
    Future<void> persist() async {
      if (idx >= 0) {
        final stored = await _repo.updateAssignment(assignment.id, body);
        assignments = assignments
            .map((a) => (a.id == assignment.id || a.id == stored.id) ? stored : a)
            .toList();
      } else {
        final stored = await _repo.createAssignment(body);
        assignments = [
          ...assignments.where((a) => a.id != assignment.id && a.id != stored.id),
          stored,
        ];
      }
      notifyListeners();
    }

    persist().catchError(
      (e) => debugPrint('[Controller] upsertAssignment error: $e'),
    );
  }

  /// Crée ou met à jour un document. Déclenche l'API en arrière-plan.
  void upsertDocument(CourseDocument doc) {
    final idx = documents.indexWhere((d) => d.id == doc.id);
    if (idx >= 0) {
      documents = [...documents]..[idx] = doc;
    } else {
      documents = [...documents, doc];
    }
    notifyListeners();
    final body = _documentToBody(doc);
    Future<void> persist() async {
      if (idx >= 0) {
        final stored = await _repo.updateDocument(doc.id, body);
        documents = documents
            .map((d) => (d.id == doc.id || d.id == stored.id) ? stored : d)
            .toList();
      } else {
        final stored = await _repo.createDocument(body);
        documents = [
          ...documents.where((d) => d.id != doc.id && d.id != stored.id),
          stored,
        ];
      }
      notifyListeners();
    }

    persist().catchError(
      (e) => debugPrint('[Controller] upsertDocument error: $e'),
    );
  }

  /// Sauvegarde les réponses intermédiaires d'une tentative (sync mock wrapper).
  void saveAttemptAnswers(String attemptId, List<List<int>> answers) {
    _repo.saveDraftAnswers(attemptId: attemptId, answers: answers)
        .catchError((e) => debugPrint('[Controller] saveDraftAnswers error: $e'));
  }

  /// Soumet une tentative identifiée par [attemptId] avec les réponses en mémoire.
  /// Retourne le score calculé sur 20 (appel API ; retourne 0.0 en cas d'erreur réseau).
  double submitAttemptSync(String attemptId) {
    // Retrouve les réponses depuis le cache local.
    final draftAnswers = getDraftAnswers(attemptId) ?? [];
    // Déclenche l'appel API asynchrone et met à jour l'état quand il revient.
    _repo.submitAttempt(attemptId, draftAnswers).then((attempt) async {
      attempts = [
        ...attempts.where((a) => a.id != attempt.id),
        attempt,
      ];
      await _loadGradebooks();
      notifyListeners();
    }).catchError((e) => debugPrint('[Controller] submitAttempt error: $e'));
    // Retourne provisoirement 0.0 ; l'UI sera rafraîchie dès la réponse API.
    return 0.0;
  }

  /// Note une copie (wrapper synchrone pour compatibilité screen).
  void gradeSubmissionSync({
    required String submissionId,
    required double grade,
    required String feedback,
  }) {
    gradeSubmission(
      submissionId: submissionId,
      grade: grade,
      feedback: feedback,
    );
  }

  /// Incrémente localement le compteur de téléchargements d'un document.
  void incrementDownload(String documentId) {
    final idx = documents.indexWhere((d) => d.id == documentId);
    if (idx < 0) return;
    final updated = documents[idx].copyWith(
      downloadsCount: documents[idx].downloadsCount + 1,
    );
    documents = [...documents]..[idx] = updated;
    notifyListeners();
    // Mise à jour API (non bloquante).
    _repo
        .updateDocument(documentId, {'downloadsCount': updated.downloadsCount})
        .catchError((e) {
          debugPrint('[Controller] incrementDownload error: $e');
          return updated;
        });
  }

  /// Génère des questions de quiz localement pour le brouillon Gemini (mode démo).
  /// En production, utiliser [generateQuizDraft] qui appelle l'API réelle.
  List<QuizQuestion> generateGeminiQuestions(String chapterHint) {
    final hint = chapterHint.trim().isEmpty ? 'le chapitre' : chapterHint.trim();
    final ts = DateTime.now().millisecondsSinceEpoch;
    return [
      QuizQuestion(
        id: 'gen_${ts}_1',
        type: QuestionType.qcm,
        text: 'Selon $hint, quelle affirmation est correcte ?',
        options: const [
          "La complexité moyenne d'un accès tableau est O(1)",
          "Une liste chaînée garantit un accès indice O(1)",
          "Un graphe est toujours acyclique",
          "Un tas binaire est une liste non ordonnée",
        ],
        correct: const [0],
        points: 5,
        explanation: 'Brouillon Gemini — à relire avant publication.',
      ),
      QuizQuestion(
        id: 'gen_${ts}_2',
        type: QuestionType.vraiFaux,
        text: 'Gemini : $hint se prête toujours à une récursion terminale.',
        options: const ['Vrai', 'Faux'],
        correct: const [1],
        points: 5,
        explanation: "Pas toujours : dépend du problème et du compilateur.",
      ),
      QuizQuestion(
        id: 'gen_${ts}_3',
        type: QuestionType.qcm,
        text: "Quelle structure modélise le mieux une file d'attente ?",
        options: const ['Pile', 'File', 'Arbre AVL', 'Table de hachage'],
        correct: const [1],
        points: 5,
        explanation: "Une file (FIFO) modélise une file d'attente.",
      ),
    ];
  }

  /// Génère un brouillon de questions via l'API Gemini gratuite (clé partagée
  /// du fichier `.env`, plan gratuit d'AI Studio) puis retombe sur le
  /// générateur local de démonstration si la clé est absente ou si le
  /// service est momentanément indisponible — l'assistant n'est jamais bloqué.
  Future<List<QuizQuestion>> generateQuizDraftAi({required String topic}) async {
    final questions = await EvaluationsAiService.instance.generateQuizQuestions(
      topic: topic,
      count: 3,
    );
    if (questions != null && questions.isNotEmpty) return questions;
    return generateGeminiQuestions(topic);
  }

  // ── Serialisation pour les appels API ────────────────────────────────────

  Map<String, dynamic> _quizToBody(Quiz q) => {
        'id': q.id,
        'courseId': q.courseId,
        'title': q.title,
        'timeLimitMin': q.timeLimitMin,
        'attemptsAllowed': q.attemptsAllowed,
        'availableFrom': q.availableFrom.toIso8601String(),
        'dueDate': q.dueDate.toIso8601String(),
        'isPublished': q.isPublished,
        'questions': q.questions
            .map((qu) => {
                  'type': qu.type.code,
                  'text': qu.text,
                  'options': qu.options,
                  'correct': qu.correct,
                  'points': qu.points,
                  'explanation': qu.explanation,
                })
            .toList(),
      };

  Map<String, dynamic> _assignmentToBody(Assignment a) => {
        'id': a.id,
        'courseId': a.courseId,
        'title': a.title,
        'instructions': a.instructions,
        'attachments': a.attachments,
        'dueDate': a.dueDate.toIso8601String(),
        'maxGrade': a.maxGrade,
        'allowLate': a.allowLate,
      };

  Map<String, dynamic> _documentToBody(CourseDocument d) => {
        'id': d.id,
        'courseId': d.courseId,
        'title': d.title,
        'description': d.description,
        'folder': d.folder.name,
        'fileUrl': d.fileUrl,
        'order': d.order,
        'visibleFrom': d.visibleFrom.toIso8601String(),
      };

  // ════════════════════════════════════════════════════════════════════════
  // UTILITAIRES PRIVÉS
  // ════════════════════════════════════════════════════════════════════════

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  /// Exécute [action] en gérant isLoading et error, retourne le résultat.
  Future<T?> _wrap<T>(Future<T> Function() action) async {
    _setLoading(true);
    try {
      final result = await action();
      error = null;
      return result;
    } on EvalApiException catch (e) {
      error = e.message;
      return null;
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _wrapVoid(Future<void> Function() action) async {
    _setLoading(true);
    try {
      await action();
      error = null;
    } on EvalApiException catch (e) {
      error = e.message;
      rethrow;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
}
