import '../models/evaluations_models.dart';
import 'package:flutter/foundation.dart';

/// Contrôleur mock M4 (ChangeNotifier) — simule quizzes, attempts, assignments,
/// submissions, documents, carnet de notes et NotificationsService (L8).
class EvaluationsController extends ChangeNotifier {
  EvaluationsController._() {
    _seed();
  }

  static final EvaluationsController instance = EvaluationsController._();

  static const String studentId = 'stu_amine';
  static const String teacherId = 'tch_leila';

  UserRole currentUserRole = UserRole.student;
  String currentUserId = studentId;
  String currentUserName = 'Amine Ben Ali';

  final List<EvalNotification> notifications = [];
  final List<String> grantedBadges = [];

  late List<LinkedCourse> courses;
  late List<String> enrolledCourseIds;
  late List<Quiz> quizzes;
  late List<QuizAttempt> attempts;
  late List<Assignment> assignments;
  late List<Submission> submissions;
  late List<CourseDocument> documents;
  late List<Map<String, String>> roster;

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

  bool get isTeacher => currentUserRole == UserRole.teacher;

  List<LinkedCourse> get accessibleCourses {
    if (isTeacher) return courses;
    return courses.where((c) => enrolledCourseIds.contains(c.id)).toList();
  }

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

  void _notify(String title, String body) {
    notifications.insert(
      0,
      EvalNotification(title: title, body: body, createdAt: DateTime.now()),
    );
  }

  void _maybeGrantBadge(String badge) {
    if (!grantedBadges.contains(badge)) {
      grantedBadges.add(badge);
    }
  }

  Quiz? quizById(String id) {
    for (final q in quizzes) {
      if (q.id == id) return q;
    }
    return null;
  }

  Assignment? assignmentById(String id) {
    for (final a in assignments) {
      if (a.id == id) return a;
    }
    return null;
  }

  CourseDocument? documentById(String id) {
    for (final d in documents) {
      if (d.id == id) return d;
    }
    return null;
  }

  QuizAttempt? attemptById(String id) {
    for (final a in attempts) {
      if (a.id == id) return a;
    }
    return null;
  }

  Submission? submissionById(String id) {
    for (final s in submissions) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<QuizAttempt> attemptsForQuiz(String quizId, {String? student}) {
    return attempts
        .where(
          (a) =>
              a.quizId == quizId && (student == null || a.studentId == student),
        )
        .toList()
      ..sort((a, b) => b.attemptNo.compareTo(a.attemptNo));
  }

  int attemptCountFor(String quizId, String student) {
    return attempts
        .where((a) => a.quizId == quizId && a.studentId == student)
        .length;
  }

  Submission? submissionFor(String assignmentId, String student) {
    for (final s in submissions) {
      if (s.assignmentId == assignmentId && s.studentId == student) return s;
    }
    return null;
  }

  bool canTakeQuiz(Quiz quiz) {
    if (!quiz.isPublished) return false;
    final now = DateTime.now();
    if (now.isBefore(quiz.availableFrom) || now.isAfter(quiz.dueDate)) {
      return false;
    }
    return attemptCountFor(quiz.id, currentUserId) < quiz.attemptsAllowed;
  }

  bool canSubmitAssignment(Assignment assignment) {
    final now = DateTime.now();
    if (now.isAfter(assignment.dueDate) && !assignment.allowLate) return false;
    return true;
  }

  List<Quiz> publishedQuizzesForStudent() {
    return quizzes
        .where(
          (q) =>
              q.isPublished && enrolledCourseIds.contains(q.courseId),
        )
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  List<Assignment> assignmentsForStudent() {
    return assignments
        .where((a) => enrolledCourseIds.contains(a.courseId))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

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

  List<Submission> copiesToGrade() {
    return submissions
        .where((s) => s.status == SubmissionStatus.submitted)
        .toList()
      ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
  }

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

  void saveAttemptAnswers(String attemptId, List<List<int>> answers) {
    final i = attempts.indexWhere((a) => a.id == attemptId);
    if (i < 0) return;
    attempts[i] = attempts[i].copyWith(answers: answers);
    notifyListeners();
  }

  double submitAttempt(String attemptId) {
    final i = attempts.indexWhere((a) => a.id == attemptId);
    final attempt = attempts[i];
    final quiz = quizById(attempt.quizId)!;
    double earned = 0;
    for (var q = 0; q < quiz.questions.length; q++) {
      final question = quiz.questions[q];
      final given = [...attempt.answers[q]]..sort();
      final expected = [...question.correct]..sort();
      if (listEquals(given, expected)) earned += question.points;
    }
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

  void deleteQuiz(String id) {
    quizzes.removeWhere((q) => q.id == id);
    attempts.removeWhere((a) => a.quizId == id);
    notifyListeners();
  }

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

  void deleteAssignment(String id) {
    assignments.removeWhere((a) => a.id == id);
    submissions.removeWhere((s) => s.assignmentId == id);
    notifyListeners();
  }

  void submitAssignment({
    required String assignmentId,
    required List<String> files,
    required String comment,
  }) {
    final assignment = assignmentById(assignmentId)!;
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

  void upsertDocument(CourseDocument doc) {
    final i = documents.indexWhere((d) => d.id == doc.id);
    if (i >= 0) {
      documents[i] = doc;
    } else {
      documents.add(doc);
    }
    notifyListeners();
  }

  void deleteDocument(String id) {
    documents.removeWhere((d) => d.id == id);
    notifyListeners();
  }

  void incrementDownload(String id) {
    final i = documents.indexWhere((d) => d.id == id);
    if (i < 0) return;
    documents[i] = documents[i].copyWith(
      downloadsCount: documents[i].downloadsCount + 1,
    );
    notifyListeners();
  }

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

  /// GET /courses/:id/gradebook — export CSV (carnet de notes)
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

  String _csv(String v) => '"${v.replaceAll('"', '""')}"';

  static String formatScore(double score) {
    return score == score.roundToDouble()
        ? score.toInt().toString()
        : score.toStringAsFixed(1);
  }

  /// Calcule la moyenne générale sur 20 d'un étudiant (quiz + devoirs notés)
  double? calculateStudentAverage(String studentId) {
    final gradesOn20 = <double>[];

    // Quiz : dernière tentative notée par quiz
    for (final q in quizzes.where((q) => q.isPublished)) {
      final userAttempts = attempts
          .where((a) => a.quizId == q.id && a.studentId == studentId && a.isSubmitted)
          .toList();
      if (userAttempts.isNotEmpty) {
        userAttempts.sort((a, b) => b.attemptNo.compareTo(a.attemptNo));
        if (userAttempts.first.score != null) {
          gradesOn20.add(userAttempts.first.score!);
        }
      }
    }

    // Devoirs notés
    for (final s in submissions.where((s) => s.studentId == studentId && s.status == SubmissionStatus.graded)) {
      final asg = assignmentById(s.assignmentId);
      if (asg != null && s.grade != null && asg.maxGrade > 0) {
        gradesOn20.add((s.grade! / asg.maxGrade) * 20);
      }
    }

    if (gradesOn20.isEmpty) return null;
    final total = gradesOn20.fold<double>(0, (sum, g) => sum + g);
    return double.parse((total / gradesOn20.length).toStringAsFixed(1));
  }

  /// Nombre total de devoirs ou quiz passés ou soumis par l'étudiant
  int studentCompletedCount(String studentId) {
    final quizCount = quizzes.where((q) => attemptCountFor(q.id, studentId) > 0).length;
    final asgCount = submissions.where((s) => s.studentId == studentId).length;
    return quizCount + asgCount;
  }

  /// Nombre d'évaluations en attente pour l'étudiant
  int studentPendingTodoCount(String studentId) {
    final pendingQuizzes = publishedQuizzesForStudent()
        .where((q) => attemptCountFor(q.id, studentId) < q.attemptsAllowed)
        .length;
    final pendingAsg = assignmentsForStudent()
        .where((a) => submissionFor(a.id, studentId) == null)
        .length;
    return pendingQuizzes + pendingAsg;
  }

  /// Nombre de copies en attente de correction pour l'enseignant
  int get pendingCopiesCount => copiesToGrade().length;

  /// POST /quizzes/generate — brouillon Gemini simulé
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
