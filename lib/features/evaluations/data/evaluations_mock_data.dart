import '../models/evaluations_models.dart';
import 'package:flutter/foundation.dart';

/// Contrôleur d'état réactif ([ChangeNotifier]) gérant l'ensemble des données
/// en mémoire du module Évaluations : cours liés, quiz, tentatives, devoirs,
/// copies déposées, supports documentaires, carnet de notes et notifications.
///
/// Exposé sous forme de singleton ([EvaluationsController.instance]) afin que
/// tous les écrans observent la même instance via `ListenableBuilder` et soient
/// rafraîchis automatiquement à chaque appel de [notifyListeners].
class EvaluationsController extends ChangeNotifier {
  /// Constructeur privé initialisant immédiatement le jeu de données initial.
  EvaluationsController._() {
    _seed();
  }

  /// Instance singleton partagée par tous les écrans de la fonctionnalité.
  static final EvaluationsController instance = EvaluationsController._();

  /// Identifiant de l'étudiant connecté par défaut en session locale.
  static const String studentId = 'stu_amine';

  /// Identifiant de l'enseignante utilisée lors du basculement de rôle.
  static const String teacherId = 'tch_leila';

  /// Rôle actif courant déterminant l'interface affichée (étudiant ou enseignant).
  UserRole currentUserRole = UserRole.student;
  String currentUserId = studentId;
  String currentUserName = 'Amine Ben Ali';

  /// Historique des notifications déclenchées par les actions métier (du plus récent au plus ancien).
  final List<EvalNotification> notifications = [];

  /// Liste des badges débloqués automatiquement selon les seuils de réussite ou de ponctualité.
  final List<String> grantedBadges = [];

  late List<LinkedCourse> courses;
  late List<String> enrolledCourseIds;
  late List<Quiz> quizzes;
  late List<QuizAttempt> attempts;
  late List<Assignment> assignments;
  late List<Submission> submissions;
  late List<CourseDocument> documents;
  late List<Map<String, String>> roster;

  /// Initialise les listes en mémoire avec des cours, inscriptions, quiz publiés/brouillon,
  /// tentatives existantes, devoirs avec ou sans retard autorisé, copies et documents PDF.
  void _seed() {
    courses = const [
      LinkedCourse(
        id: 'course_algo_1',
        title: 'Algorithmique',
        subject: 'Algorithmique',
        level: 'L2',
        teacherId: teacherId,
        teacherName: 'Dr. Leila Mansour',
      ),
      LinkedCourse(
        id: 'course_bdd_1',
        title: 'Bases de Données',
        subject: 'Bases de Données',
        level: 'L2',
        teacherId: teacherId,
        teacherName: 'Dr. Leila Mansour',
      ),
      LinkedCourse(
        id: 'course_reseau_1',
        title: 'Réseaux & Sécurité',
        subject: 'Réseaux & Sécurité',
        level: 'L3',
        teacherId: teacherId,
        teacherName: 'Dr. Leila Mansour',
      ),
    ];
    enrolledCourseIds = ['course_algo_1', 'course_bdd_1'];

    roster = const [
      {'id': studentId, 'name': 'Amine Ben Ali'},
      {'id': 'stu_sara', 'name': 'Sara Trabelsi'},
      {'id': 'stu_youssef', 'name': 'Youssef Kacem'},
    ];

    quizzes = [
      Quiz(
        id: 'quiz_algo_listes',
        courseId: 'course_algo_1',
        courseTitle: 'Algorithmique',
        teacherId: teacherId,
        teacherName: 'Dr. Leila Mansour',
        title: 'Structures linéaires',
        timeLimitMin: 12,
        attemptsAllowed: 2,
        availableFrom: DateTime(2026, 10, 20, 8),
        dueDate: DateTime(2026, 10, 30, 23, 59),
        isPublished: true,
        questions: const [
          QuizQuestion(
            id: 'q1',
            type: QuestionType.qcm,
            text: 'Quelle structure permet un accès en O(1) à un élément par indice ?',
            options: ['Liste chaînée', 'Tableau', 'Pile', 'File'],
            correct: [1],
            points: 5,
            explanation: 'Un tableau offre un accès direct par indice.',
          ),
          QuizQuestion(
            id: 'q2',
            type: QuestionType.vraiFaux,
            text: 'Une pile suit le principe FIFO.',
            options: ['Vrai', 'Faux'],
            correct: [1],
            points: 5,
            explanation: 'Une pile est LIFO ; FIFO décrit une file.',
          ),
          QuizQuestion(
            id: 'q3',
            type: QuestionType.qcm,
            text: 'Quelles opérations sont typiques d\'une file ? (plusieurs réponses)',
            options: ['enqueue', 'dequeue', 'push', 'peek'],
            correct: [0, 1, 3],
            points: 10,
            explanation: 'push appartient à la pile ; peek peut exister sur une file.',
          ),
        ],
      ),
      Quiz(
        id: 'quiz_bdd_rel',
        courseId: 'course_bdd_1',
        courseTitle: 'Bases de Données',
        teacherId: teacherId,
        teacherName: 'Dr. Leila Mansour',
        title: 'Modèle relationnel',
        timeLimitMin: 10,
        attemptsAllowed: 1,
        availableFrom: DateTime(2026, 10, 22, 8),
        dueDate: DateTime(2026, 11, 5, 23, 59),
        isPublished: true,
        questions: const [
          QuizQuestion(
            id: 'q1',
            type: QuestionType.qcm,
            text: 'Une clé primaire peut-elle contenir des NULL ?',
            options: ['Oui', 'Non', 'Seulement en MySQL', 'Uniquement si unique'],
            correct: [1],
            points: 10,
            explanation: 'Une clé primaire est NOT NULL et unique.',
          ),
          QuizQuestion(
            id: 'q2',
            type: QuestionType.vraiFaux,
            text: 'La 3NF interdit toute dépendance transitive des attributs non-clés.',
            options: ['Vrai', 'Faux'],
            correct: [0],
            points: 10,
            explanation: 'C\'est la définition classique de la 3e forme normale.',
          ),
        ],
      ),
      Quiz(
        id: 'quiz_algo_draft',
        courseId: 'course_algo_1',
        courseTitle: 'Algorithmique',
        teacherId: teacherId,
        teacherName: 'Dr. Leila Mansour',
        title: 'Récursivité (brouillon)',
        timeLimitMin: 15,
        attemptsAllowed: 1,
        availableFrom: DateTime(2026, 11, 1, 8),
        dueDate: DateTime(2026, 11, 10, 23, 59),
        isPublished: false,
        questions: const [
          QuizQuestion(
            id: 'q1',
            type: QuestionType.vraiFaux,
            text: 'Tout algorithme récursif possède un cas de base.',
            options: ['Vrai', 'Faux'],
            correct: [0],
            points: 10,
            explanation: 'Sans cas de base, la récursion ne termine pas.',
          ),
        ],
      ),
    ];

    attempts = [
      QuizAttempt(
        id: 'att_amine_listes_1',
        quizId: 'quiz_algo_listes',
        studentId: studentId,
        studentName: 'Amine Ben Ali',
        attemptNo: 1,
        answers: const [
          [1],
          [0],
          [0, 1],
        ],
        score: 10,
        startedAt: DateTime(2026, 10, 24, 14, 2),
        submittedAt: DateTime(2026, 10, 24, 14, 11),
      ),
      QuizAttempt(
        id: 'att_sara_listes_1',
        quizId: 'quiz_algo_listes',
        studentId: 'stu_sara',
        studentName: 'Sara Trabelsi',
        attemptNo: 1,
        answers: const [
          [1],
          [1],
          [0, 1, 3],
        ],
        score: 20,
        startedAt: DateTime(2026, 10, 23, 10, 0),
        submittedAt: DateTime(2026, 10, 23, 10, 8),
      ),
    ];

    assignments = [
      Assignment(
        id: 'asg_tp_listes',
        courseId: 'course_algo_1',
        courseTitle: 'Algorithmique',
        teacherId: teacherId,
        teacherName: 'Dr. Leila Mansour',
        title: 'TP — Listes chaînées',
        instructions:
            'Implémentez une liste simplement chaînée (ajout, suppression, recherche). '
            'Déposez un ZIP contenant le code et un README de 1 page.',
        attachments: const ['consigne_tp_listes.pdf'],
        dueDate: DateTime(2026, 10, 28, 23, 59),
        maxGrade: 20,
        allowLate: true,
      ),
      Assignment(
        id: 'asg_sql',
        courseId: 'course_bdd_1',
        courseTitle: 'Bases de Données',
        teacherId: teacherId,
        teacherName: 'Dr. Leila Mansour',
        title: 'Mini-projet SQL',
        instructions:
            'Modélisez une bibliothèque universitaire (MCD + script SQL). '
            'Le script doit contenir au moins 8 requêtes dont 2 jointures.',
        attachments: const ['cahier_des_charges_sql.pdf'],
        dueDate: DateTime(2026, 11, 8, 23, 59),
        maxGrade: 20,
        allowLate: false,
      ),
      Assignment(
        id: 'asg_complexite',
        courseId: 'course_algo_1',
        courseTitle: 'Algorithmique',
        teacherId: teacherId,
        teacherName: 'Dr. Leila Mansour',
        title: 'Rapport complexité',
        instructions:
            'Comparez expérimentalement tri insertion et tri fusion sur 3 tailles de tableaux. '
            'Joignez courbes et interprétation (2 pages max).',
        dueDate: DateTime(2026, 10, 20, 23, 59),
        maxGrade: 10,
        allowLate: false,
      ),
    ];

    submissions = [
      Submission(
        id: 'sub_amine_tp',
        assignmentId: 'asg_tp_listes',
        studentId: studentId,
        studentName: 'Amine Ben Ali',
        fileUrls: const ['amine_tp_listes.zip'],
        comment: 'README inclus, tests unitaires dans /test.',
        submittedAt: DateTime(2026, 10, 26, 11, 20),
        isLate: false,
        status: SubmissionStatus.submitted,
      ),
      Submission(
        id: 'sub_sara_tp',
        assignmentId: 'asg_tp_listes',
        studentId: 'stu_sara',
        studentName: 'Sara Trabelsi',
        fileUrls: const ['sara_listes.zip'],
        comment: 'Implémentation doublement chaînée en bonus.',
        submittedAt: DateTime(2026, 10, 25, 18, 40),
        isLate: false,
        status: SubmissionStatus.graded,
        grade: 17,
        feedback: 'Très bon travail. Pensez à documenter la complexité.',
        gradedAt: DateTime(2026, 10, 26, 9, 15),
      ),
    ];

    documents = [
      CourseDocument(
        id: 'doc_poly_algo',
        courseId: 'course_algo_1',
        courseTitle: 'Algorithmique',
        teacherId: teacherId,
        teacherName: 'Dr. Leila Mansour',
        title: 'Polycopié — Chapitre 1',
        description: 'Complexité, notations de Landau, exemples corrigés.',
        folder: DocumentFolder.polycopies,
        fileUrl: 'poly_algo_ch1.pdf',
        order: 1,
        visibleFrom: DateTime(2026, 10, 1),
        downloadsCount: 48,
      ),
      CourseDocument(
        id: 'doc_corrige_td2',
        courseId: 'course_algo_1',
        courseTitle: 'Algorithmique',
        teacherId: teacherId,
        teacherName: 'Dr. Leila Mansour',
        title: 'Corrigé TD 2 — Listes',
        description: 'Solutions commentées des exercices 1 à 6.',
        folder: DocumentFolder.corriges,
        fileUrl: 'corrige_td2_listes.pdf',
        order: 2,
        visibleFrom: DateTime(2026, 10, 18),
        downloadsCount: 31,
      ),
      CourseDocument(
        id: 'doc_annales_bdd',
        courseId: 'course_bdd_1',
        courseTitle: 'Bases de Données',
        teacherId: teacherId,
        teacherName: 'Dr. Leila Mansour',
        title: 'Annales session 2025',
        description: 'Sujet + barème. Durée 1h30.',
        folder: DocumentFolder.annales,
        fileUrl: 'annales_bdd_2025.pdf',
        order: 1,
        visibleFrom: DateTime(2026, 10, 10),
        downloadsCount: 22,
      ),
    ];
  }

  /// Indique si le profil actuellement actif dispose des privilèges enseignant.
  bool get isTeacher => currentUserRole == UserRole.teacher;

  /// Retourne tous les cours pour un enseignant, ou uniquement les cours inscrits pour un étudiant.
  List<LinkedCourse> get accessibleCourses {
    if (isTeacher) return courses;
    return courses.where((c) => enrolledCourseIds.contains(c.id)).toList();
  }

  /// Bascule entre le compte étudiant et le compte enseignant puis notifie les écouteurs UI.
  void toggleCurrentUserRole() {
    if (isTeacher) {
      currentUserRole = UserRole.student;
      currentUserId = studentId;
      currentUserName = 'Amine Ben Ali';
    } else {
      currentUserRole = UserRole.teacher;
      currentUserId = teacherId;
      currentUserName = 'Dr. Leila Mansour';
    }
    notifyListeners();
  }

  /// Insère une nouvelle notification en tête de pile avec l'horodatage courant.
  void _notify(String title, String body) {
    notifications.insert(
      0,
      EvalNotification(title: title, body: body, createdAt: DateTime.now()),
    );
  }

  /// Ajoute un badge de progression sans doublon s'il n'a pas encore été attribué.
  void _maybeGrantBadge(String badge) {
    if (!grantedBadges.contains(badge)) {
      grantedBadges.add(badge);
    }
  }

  /// Recherche un [Quiz] par identifiant, ou renvoie `null` s'il a été supprimé.
  Quiz? quizById(String id) {
    for (final q in quizzes) {
      if (q.id == id) return q;
    }
    return null;
  }

  /// Recherche un [Assignment] par identifiant, ou renvoie `null` s'il est introuvable.
  Assignment? assignmentById(String id) {
    for (final a in assignments) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Recherche un [CourseDocument] par identifiant dans la liste des supports.
  CourseDocument? documentById(String id) {
    for (final d in documents) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Recherche une [QuizAttempt] précise par son identifiant unique.
  QuizAttempt? attemptById(String id) {
    for (final a in attempts) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Recherche une copie [Submission] par son identifiant unique.
  Submission? submissionById(String id) {
    for (final s in submissions) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Récupère les tentatives d'un quiz (filtrées optionnellement par étudiant),
  /// triées de la tentative la plus récente à la plus ancienne.
  List<QuizAttempt> attemptsForQuiz(String quizId, {String? student}) {
    return attempts
        .where(
          (a) =>
              a.quizId == quizId && (student == null || a.studentId == student),
        )
        .toList()
      ..sort((a, b) => b.attemptNo.compareTo(a.attemptNo));
  }

  /// Compte le nombre de tentatives déjà engagées par un étudiant sur un quiz donné.
  int attemptCountFor(String quizId, String student) {
    return attempts
        .where((a) => a.quizId == quizId && a.studentId == student)
        .length;
  }

  /// Retourne le dépôt existant d'un étudiant pour un devoir donné, ou `null` s'il n'a rien remis.
  Submission? submissionFor(String assignmentId, String student) {
    for (final s in submissions) {
      if (s.assignmentId == assignmentId && s.studentId == student) return s;
    }
    return null;
  }

  /// Vérifie qu'un étudiant est autorisé à démarrer un quiz : publication active,
  /// date courante comprise entre `availableFrom` et `dueDate`, et quota de tentatives non atteint.
  bool canTakeQuiz(Quiz quiz) {
    if (!quiz.isPublished) return false;
    final now = DateTime.now();
    if (now.isBefore(quiz.availableFrom) || now.isAfter(quiz.dueDate)) {
      return false;
    }
    return attemptCountFor(quiz.id, currentUserId) < quiz.attemptsAllowed;
  }

  /// Détermine si le dépôt d'un devoir reste ouvert en tenant compte de l'échéance
  /// et de l'option `allowLate` autorisant ou bloquant les remises hors délai.
  bool canSubmitAssignment(Assignment assignment) {
    final now = DateTime.now();
    if (now.isAfter(assignment.dueDate) && !assignment.allowLate) return false;
    return true;
  }

  /// Liste les quiz publiés appartenant aux cours auxquels l'étudiant est inscrit,
  /// ordonnés par échéance croissante.
  List<Quiz> publishedQuizzesForStudent() {
    return quizzes
        .where(
          (q) =>
              q.isPublished && enrolledCourseIds.contains(q.courseId),
        )
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  /// Liste les devoirs rattachés aux cours suivis par l'étudiant, triés par date limite.
  List<Assignment> assignmentsForStudent() {
    return assignments
        .where((a) => enrolledCourseIds.contains(a.courseId))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  /// Filtre les documents accessibles selon le cours, le dossier thématique, l'inscription
  /// de l'étudiant et la date de visibilité (`visibleFrom`), puis les trie par `order`.
  List<CourseDocument> visibleDocuments({String? courseId, DocumentFolder? folder}) {
    final now = DateTime.now();
    return documents.where((d) {
      final courseOk = courseId == null || d.courseId == courseId;
      final folderOk = folder == null || d.folder == folder;
      final access = isTeacher || enrolledCourseIds.contains(d.courseId);
      final visible = isTeacher || !d.visibleFrom.isAfter(now);
      return courseOk && folderOk && access && visible;
    }).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Retourne la file des copies en attente de correction (`SubmissionStatus.submitted`),
  /// triées par ordre chronologique d'arrivée (FIFO).
  List<Submission> copiesToGrade() {
    return submissions
        .where((s) => s.status == SubmissionStatus.submitted)
        .toList()
      ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
  }

  /// Initialise une nouvelle tentative ([QuizAttempt]) à l'ouverture de `QuizTakeScreen`,
  /// prépare un tableau de réponses vides par question et notifie les vues abonnées.
  String startAttempt(String quizId) {
    final quiz = quizById(quizId)!;
    final no = attemptCountFor(quizId, currentUserId) + 1;
    final id = 'att_${currentUserId}_${quizId}_$no';
    attempts.add(
      QuizAttempt(
        id: id,
        quizId: quizId,
        studentId: currentUserId,
        studentName: currentUserName,
        attemptNo: no,
        answers: List.generate(quiz.questions.length, (_) => <int>[]),
        startedAt: DateTime.now(),
      ),
    );
    notifyListeners();
    return id;
  }

  /// Sauvegarde à chaud les choix cochés par l'étudiant pendant le passage du quiz
  /// et propage la mise à jour via [notifyListeners].
  void saveAttemptAnswers(String attemptId, List<List<int>> answers) {
    final i = attempts.indexWhere((a) => a.id == attemptId);
    if (i < 0) return;
    attempts[i] = attempts[i].copyWith(answers: answers);
    notifyListeners();
  }

  /// Clôture une tentative de quiz et exécute la correction automatique :
  /// compare les indices cochés triés à `question.correct` via `listEquals`,
  /// ramène le total des points obtenus sur 20, attribue éventuellement le badge `Studieux`,
  /// enregistre une notification et déclenche [notifyListeners].
  double submitAttempt(String attemptId) {
    final i = attempts.indexWhere((a) => a.id == attemptId);
    final attempt = attempts[i];
    final quiz = quizById(attempt.quizId)!;
    double earned = 0;
    for (var q = 0; q < quiz.questions.length; q++) {
      final question = quiz.questions[q];
      // Tri des deux listes d'indices pour comparer les ensembles de réponses indépendamment de l'ordre de clic.
      final given = [...attempt.answers[q]]..sort();
      final expected = [...question.correct]..sort();
      if (listEquals(given, expected)) earned += question.points;
    }
    // Normalisation proportionnelle du score sur 20 à partir du barème total du quiz.
    final scoreSur20 = quiz.totalPoints == 0
        ? 0.0
        : (earned / quiz.totalPoints) * 20;
    attempts[i] = attempt.copyWith(
      score: double.parse(scoreSur20.toStringAsFixed(1)),
      submittedAt: DateTime.now(),
    );
    if (scoreSur20 >= 10) {
      final passed = attempts
          .where(
            (a) =>
                a.studentId == currentUserId &&
                a.isSubmitted &&
                (a.score ?? 0) >= 10,
          )
          .length;
      if (passed >= 10) _maybeGrantBadge('Studieux');
    }
    _notify(
      'Quiz soumis',
      '${quiz.title} · ${formatScore(scoreSur20)} / 20 (correction automatique)',
    );
    notifyListeners();
    return scoreSur20;
  }

  /// Crée ou met à jour un [Quiz] (en brouillon ou publié), émet une notification
  /// en cas de publication et rafraîchit les observateurs via [notifyListeners].
  void upsertQuiz(Quiz quiz, {required bool publish}) {
    final saved = quiz.copyWith(isPublished: publish);
    final i = quizzes.indexWhere((q) => q.id == saved.id);
    if (i >= 0) {
      quizzes[i] = saved;
    } else {
      quizzes.add(saved);
    }
    if (publish) {
      _notify(
        'Nouvelle évaluation',
        'Quiz « ${saved.title} » publié dans ${saved.courseTitle}.',
      );
    }
    notifyListeners();
  }

  /// Bascule l'état de publication (`isPublished`) d'un quiz existant depuis le tableau enseignant.
  void publishQuiz(String id, bool published) {
    final i = quizzes.indexWhere((q) => q.id == id);
    if (i < 0) return;
    quizzes[i] = quizzes[i].copyWith(isPublished: published);
    if (published) {
      _notify(
        'Nouvelle évaluation',
        'Quiz « ${quizzes[i].title} » publié.',
      );
    }
    notifyListeners();
  }

  /// Supprime un quiz ainsi que toutes les tentatives associées en cascade, puis notifie l'UI.
  void deleteQuiz(String id) {
    quizzes.removeWhere((q) => q.id == id);
    attempts.removeWhere((a) => a.quizId == id);
    notifyListeners();
  }

  /// Ajoute un nouveau devoir (avec notification) ou remplace un devoir existant lors d'une modification.
  void upsertAssignment(Assignment assignment) {
    final i = assignments.indexWhere((a) => a.id == assignment.id);
    if (i >= 0) {
      assignments[i] = assignment;
    } else {
      assignments.add(assignment);
      _notify(
        'Nouveau devoir',
        '« ${assignment.title} » — échéance à surveiller.',
      );
    }
    notifyListeners();
  }

  /// Supprime un devoir et purge en cascade les copies rattachées avant d'appeler [notifyListeners].
  void deleteAssignment(String id) {
    assignments.removeWhere((a) => a.id == id);
    submissions.removeWhere((s) => s.assignmentId == id);
    notifyListeners();
  }

  /// Enregistre ou remplace le dépôt d'un étudiant sur un devoir.
  /// Détecte automatiquement le retard (`DateTime.now().isAfter(assignment.dueDate)`),
  /// réinitialise le statut à `SubmissionStatus.submitted`, vérifie le badge `Ponctuel`
  /// et déclenche [notifyListeners].
  void submitAssignment({
    required String assignmentId,
    required List<String> files,
    required String comment,
  }) {
    final assignment = assignmentById(assignmentId)!;
    // Détection automatique de remise hors délai par comparaison avec la date limite du devoir.
    final late = DateTime.now().isAfter(assignment.dueDate);
    final existing = submissionFor(assignmentId, currentUserId);
    final sub = Submission(
      id: existing?.id ?? 'sub_${currentUserId}_$assignmentId',
      assignmentId: assignmentId,
      studentId: currentUserId,
      studentName: currentUserName,
      fileUrls: files,
      comment: comment,
      submittedAt: DateTime.now(),
      isLate: late,
      status: SubmissionStatus.submitted,
    );
    if (existing == null) {
      submissions.add(sub);
    } else {
      final i = submissions.indexWhere((s) => s.id == existing.id);
      submissions[i] = sub;
    }
    if (!late) {
      final onTime = submissions
          .where((s) => s.studentId == currentUserId && !s.isLate)
          .length;
      if (onTime >= 5) _maybeGrantBadge('Ponctuel');
    }
    _notify(
      'Dépôt reçu',
      '${assignment.title}${late ? ' (en retard)' : ''}.',
    );
    notifyListeners();
  }

  /// Attribue une note et un commentaire de correction à une copie étudiante,
  /// passe son statut à `SubmissionStatus.graded`, publie une notification et appelle [notifyListeners].
  void gradeSubmission({
    required String submissionId,
    required double grade,
    required String feedback,
  }) {
    final i = submissions.indexWhere((s) => s.id == submissionId);
    submissions[i] = submissions[i].copyWith(
      status: SubmissionStatus.graded,
      grade: grade,
      feedback: feedback,
      gradedAt: DateTime.now(),
    );
    final graded = submissions
        .where((s) => s.status == SubmissionStatus.graded)
        .length;
    if (graded >= 20) _maybeGrantBadge('Correcteur');
    final assignment = assignmentById(submissions[i].assignmentId);
    _notify(
      'Note publiée',
      '${assignment?.title ?? 'Devoir'} · ${submissions[i].studentName} : '
          '${grade.toStringAsFixed(0)} / ${assignment?.maxGrade.toStringAsFixed(0) ?? '20'}',
    );
    notifyListeners();
  }

  /// Ajoute un support de cours ou met à jour ses métadonnées puis rafraîchit les vues abonnées.
  void upsertDocument(CourseDocument doc) {
    final i = documents.indexWhere((d) => d.id == doc.id);
    if (i >= 0) {
      documents[i] = doc;
    } else {
      documents.add(doc);
    }
    notifyListeners();
  }

  /// Supprime un document pédagogique par identifiant et notifie les écouteurs.
  void deleteDocument(String id) {
    documents.removeWhere((d) => d.id == id);
    notifyListeners();
  }

  /// Incrémente le compteur de téléchargements d'un document et met à jour l'affichage en temps réel.
  void incrementDownload(String id) {
    final i = documents.indexWhere((d) => d.id == id);
    if (i < 0) return;
    documents[i] = documents[i].copyWith(
      downloadsCount: documents[i].downloadsCount + 1,
    );
    notifyListeners();
  }

  /// Construit dynamiquement les lignes du carnet de notes ([GradebookRow]) en croisant
  /// la liste des étudiants (`roster`) avec les quiz publiés (dernière tentative soumise)
  /// et les devoirs (état du dépôt et note obtenue), filtrables par cours ou par étudiant.
  List<GradebookRow> gradebook({String? courseId, String? student}) {
    final rows = <GradebookRow>[];
    for (final quiz in quizzes.where((q) => q.isPublished)) {
      if (courseId != null && quiz.courseId != courseId) continue;
      final students = student == null
          ? roster
          : roster.where((r) => r['id'] == student);
      for (final st in students) {
        final att = attempts
            .where(
              (a) =>
                  a.quizId == quiz.id &&
                  a.studentId == st['id'] &&
                  a.isSubmitted,
            )
            .toList();
        att.sort((a, b) => b.attemptNo.compareTo(a.attemptNo));
        rows.add(
          GradebookRow(
            studentId: st['id']!,
            studentName: st['name']!,
            courseTitle: quiz.courseTitle,
            itemType: 'Quiz',
            itemTitle: quiz.title,
            grade: att.isEmpty ? null : att.first.score,
            maxGrade: 20,
            status: att.isEmpty ? 'Non rendu' : 'Noté',
            datedAt: att.isEmpty ? null : att.first.submittedAt,
          ),
        );
      }
    }
    for (final asg in assignments) {
      if (courseId != null && asg.courseId != courseId) continue;
      final students = student == null
          ? roster
          : roster.where((r) => r['id'] == student);
      for (final st in students) {
        final sub = submissionFor(asg.id, st['id']!);
        rows.add(
          GradebookRow(
            studentId: st['id']!,
            studentName: st['name']!,
            courseTitle: asg.courseTitle,
            itemType: 'Devoir',
            itemTitle: asg.title,
            grade: sub?.grade,
            maxGrade: asg.maxGrade,
            status: sub == null
                ? 'Non rendu'
                : (sub.status == SubmissionStatus.graded
                    ? 'Noté'
                    : 'Déposé'),
            datedAt: sub?.gradedAt ?? sub?.submittedAt,
          ),
        );
      }
    }
    return rows;
  }

  /// Sérialise le carnet de notes filtré au format CSV (séparateur point-virgule compatible tableurs)
  /// avec échappement des guillemets doubles.
  String exportGradebookCsv({String? courseId, String? student}) {
    final rows = gradebook(courseId: courseId, student: student);
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

  /// Encadre une valeur texte de guillemets et double les guillemets internes conformément à RFC 4180.
  String _csv(String v) => '"${v.replaceAll('"', '""')}"';

  /// Formate un score numérique sans décimale s'il est entier, ou avec un chiffre après la virgule sinon.
  static String formatScore(double score) {
    return score == score.roundToDouble()
        ? score.toInt().toString()
        : score.toStringAsFixed(1);
  }

  /// Génère localement trois questions préremplies (QCM et Vrai/Faux) à partir d'un thème
  /// de chapitre afin d'alimenter le brouillon assisté dans `QuizWizardScreen`.
  List<QuizQuestion> generateGeminiQuestions(String chapterHint) {
    final hint = chapterHint.trim().isEmpty ? 'le chapitre' : chapterHint.trim();
    return [
      QuizQuestion(
        id: 'gen_${DateTime.now().millisecondsSinceEpoch}_1',
        type: QuestionType.qcm,
        text: 'Selon $hint, quelle affirmation est correcte ?',
        options: const [
          'La complexité moyenne d\'un accès tableau est O(1)',
          'Une liste chaînée garantit un accès indice O(1)',
          'Un graphe est toujours acyclique',
          'Un tas binaire est une liste non ordonnée',
        ],
        correct: const [0],
        points: 5,
        explanation: 'Brouillon Gemini — à relire avant publication.',
      ),
      QuizQuestion(
        id: 'gen_${DateTime.now().millisecondsSinceEpoch}_2',
        type: QuestionType.vraiFaux,
        text: 'Gemini : $hint se prête toujours à une récursion terminale.',
        options: const ['Vrai', 'Faux'],
        correct: const [1],
        points: 5,
        explanation: 'Pas toujours : dépend du problème et du compilateur.',
      ),
      QuizQuestion(
        id: 'gen_${DateTime.now().millisecondsSinceEpoch}_3',
        type: QuestionType.qcm,
        text: 'Quelle structure modélise le mieux une file d\'attente ?',
        options: const ['Pile', 'File', 'Arbre AVL', 'Table de hachage'],
        correct: const [1],
        points: 5,
        explanation: 'Une file (FIFO) modélise une file d\'attente.',
      ),
    ];
  }
}
