import 'package:flutter/foundation.dart';
import '../models/courses_models.dart';

// ============================================================================
// CONTRÔLEUR D'ÉTAT & DONNÉES DE DÉMONSTRATION — MODULE M2 : COURS
// Hérite de [ChangeNotifier] (même pattern que les contrôleurs des autres
// modules) pour synchroniser toutes les vues du module.
// Les ids de cours sont alignés sur les mocks des modules partenaires
// (évaluations et marketplace) pour que les intégrations pointent
// vers les mêmes cours lors des démos.
// ============================================================================

class CoursesController extends ChangeNotifier {
  /// Instance singleton partagée à travers tous les écrans du module Cours
  static final CoursesController instance = CoursesController._internal();

  CoursesController._internal() {
    _seedInitialData();
  }

  /// Utilisateur connecté simulé (`users.uid` et `users.role`)
  String currentUserId = 'user_me';
  String currentUserName = 'Yasmine Ben Ali';
  CourseRole currentUserRole = CourseRole.student;

  bool get isTeacher => currentUserRole == CourseRole.teacher;

  /// Bascule Étudiant ↔ Enseignant pour tester les deux vues de l'onglet Cours
  /// (l'enseignant simulé est le même que celui du mock M4 : Dr. Leila Mansour)
  void toggleCurrentUserRole() {
    if (currentUserRole == CourseRole.student) {
      currentUserRole = CourseRole.teacher;
      currentUserName = 'Dr. Leila Mansour';
    } else {
      currentUserRole = CourseRole.student;
      currentUserName = 'Yasmine Ben Ali';
    }
    notifyListeners();
  }

  /// Matières identiques à celles de la Marketplace (M5) — cohérence des filtres
  static const List<String> subjects = [
    'Algorithmique',
    'Bases de Données',
    'Réseaux & Sécurité',
    'Intelligence Artificielle',
    'Génie Logiciel',
    'Mathématiques',
    'Développement Mobile',
  ];

  /// Niveaux académiques (L1 à M2)
  static const List<String> levels = ['L1', 'L2', 'L3', 'M1', 'M2'];

  // Collections simulées en mémoire (collections Firestore de M2)
  final List<Course> _courses = [];
  final Map<String, List<Chapter>> _chaptersByCourse = {};
  final List<Enrollment> _enrollments = [];

  // --- Accesseurs en lecture seule -------------------------------------------

  List<Course> get allCourses => List.unmodifiable(_courses);

  /// Catalogue public : uniquement les cours publiés
  List<Course> get publishedCourses =>
      _courses.where((c) => c.isPublished).toList(growable: false);

  /// Cours de l'enseignant connecté (`GET /courses?teacherId=me`)
  List<Course> get teacherCourses =>
      _courses.where((c) => c.teacherId == currentUserId).toList(growable: false);

  /// Inscriptions de l'étudiant connecté (`GET /enrollments/me`)
  List<Enrollment> get myEnrollments =>
      _enrollments.where((e) => e.studentId == currentUserId).toList(growable: false);

  /// Cours suivis par l'étudiant connecté
  List<Course> get enrolledCourses => myEnrollments
      .map((e) => courseById(e.courseId))
      .whereType<Course>()
      .toList(growable: false);

  Course? courseById(String courseId) {
    for (final c in _courses) {
      if (c.id == courseId) return c;
    }
    return null;
  }

  /// Chapitres d'un cours triés par ordre (`GET /courses/:id/chapters`)
  List<Chapter> chaptersOf(String courseId) =>
      List.unmodifiable(_chaptersByCourse[courseId] ?? const []);

  /// Durée totale du cours en minutes (somme des chapitres)
  int totalDurationMin(String courseId) => chaptersOf(courseId)
      .fold(0, (total, chapter) => total + chapter.durationMin);

  /// Inscription de l'utilisateur courant à un cours donné
  Enrollment? enrollmentFor(String courseId) {
    for (final e in myEnrollments) {
      if (e.courseId == courseId) return e;
    }
    return null;
  }

  bool isEnrolled(String courseId) => enrollmentFor(courseId) != null;

  /// Inscriptions à un cours (`GET /courses/:id/students` — enseignant)
  List<Enrollment> enrollmentsOf(String courseId) => _enrollments
      .where((e) => e.courseId == courseId)
      .toList(growable: false);

  /// Progression d'une inscription (0.0 → 1.0) d'après les chapitres terminés
  double progressOf(Enrollment enrollment) {
    final chapters = chaptersOf(enrollment.courseId);
    if (chapters.isEmpty) return 0;
    return enrollment.completedChapterIds.length / chapters.length;
  }

  /// Progression moyenne d'un cours (vue enseignant)
  double courseAverageProgress(String courseId) {
    final enrollments = enrollmentsOf(courseId);
    if (enrollments.isEmpty) return 0;
    return enrollments.fold<double>(
          0,
          (total, e) => total + progressOf(e),
        ) /
        enrollments.length;
  }

  // --- Métier 1 : assistant de création de cours (enseignant) ----------------

  /// Crée un cours en brouillon (`POST /courses`)
  Course createCourse({
    required String title,
    required String subject,
    required String level,
    required String description,
    String? coverImageUrl,
  }) {
    final course = Course(
      id: 'course_${DateTime.now().millisecondsSinceEpoch}',
      teacherId: currentUserId,
      teacherName: currentUserName,
      teacherVerified: isTeacher,
      title: title,
      subject: subject,
      level: level,
      description: description,
      coverImageUrl: coverImageUrl,
      createdAt: DateTime.now(),
    );
    _courses.add(course);
    _chaptersByCourse[course.id] = [];
    notifyListeners();
    return course;
  }

  /// Modifie un cours existant (`PATCH /courses/:id`)
  void updateCourse(
    String courseId, {
    required String title,
    required String subject,
    required String level,
    required String description,
    String? coverImageUrl,
  }) {
    final course = courseById(courseId);
    if (course == null) return;
    course.title = title;
    course.subject = subject;
    course.level = level;
    course.description = description;
    course.coverImageUrl = coverImageUrl;
    notifyListeners();
  }

  /// Supprime un cours et ses chapitres / inscriptions (`DELETE /courses/:id`)
  void deleteCourse(String courseId) {
    _courses.removeWhere((c) => c.id == courseId);
    _chaptersByCourse.remove(courseId);
    _enrollments.removeWhere((e) => e.courseId == courseId);
    notifyListeners();
  }

  /// Publie ou masque un cours (`PATCH /courses/:id/publish`).
  /// Retourne false si la publication est refusée (aucun chapitre).
  bool setPublished(String courseId, bool published) {
    final course = courseById(courseId);
    if (course == null) return false;
    if (published && chaptersOf(courseId).isEmpty) return false;
    course.isPublished = published;
    notifyListeners();
    return true;
  }

  /// Ajoute un chapitre (`POST /courses/:id/chapters`)
  Chapter addChapter(
    String courseId, {
    required String title,
    required ChapterType type,
    String? content,
    required int durationMin,
  }) {
    final chapters = _chaptersByCourse.putIfAbsent(courseId, () => []);
    final chapter = Chapter(
      id: 'chapter_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      type: type,
      content: content,
      durationMin: durationMin,
      order: chapters.length,
    );
    chapters.add(chapter);
    final course = courseById(courseId);
    if (course != null) course.chaptersCount = chapters.length;
    notifyListeners();
    return chapter;
  }

  /// Modifie un chapitre (`PATCH /courses/:id/chapters/:chapterId`)
  void updateChapter(
    String courseId,
    String chapterId, {
    required String title,
    required int durationMin,
    String? content,
  }) {
    final chapters = _chaptersByCourse[courseId];
    if (chapters == null) return;
    for (final chapter in chapters) {
      if (chapter.id == chapterId) {
        chapter.title = title;
        chapter.durationMin = durationMin;
        if (content != null) chapter.content = content;
        break;
      }
    }
    notifyListeners();
  }

  /// Supprime un chapitre et réindexe les suivants (`DELETE /courses/:id/chapters/:id`)
  void deleteChapter(String courseId, String chapterId) {
    final chapters = _chaptersByCourse[courseId];
    if (chapters == null) return;
    chapters.removeWhere((c) => c.id == chapterId);
    for (var i = 0; i < chapters.length; i++) {
      chapters[i].order = i;
    }
    final course = courseById(courseId);
    if (course != null) course.chaptersCount = chapters.length;
    // Retire le chapitre des progressions et corrige la reprise de lecture
    for (final e in _enrollments.where((e) => e.courseId == courseId)) {
      e.completedChapterIds.remove(chapterId);
      if (e.lastChapterId == chapterId) {
        e.lastChapterId = chapters.isEmpty ? null : chapters.first.id;
      }
    }
    notifyListeners();
  }

  /// Réordonne les chapitres après un glisser-déposer
  /// (`PATCH /courses/:id/chapters/reorder`).
  /// [newIndex] est déjà ajusté par `ReorderableListView.onReorderItem`
  /// (position finale d'insertion après retrait de l'élément déplacé).
  void reorderChapters(String courseId, int oldIndex, int newIndex) {
    final chapters = _chaptersByCourse[courseId];
    if (chapters == null ||
        oldIndex < 0 ||
        oldIndex >= chapters.length ||
        newIndex < 0 ||
        newIndex >= chapters.length) {
      return;
    }
    final chapter = chapters.removeAt(oldIndex);
    chapters.insert(newIndex, chapter);
    for (var i = 0; i < chapters.length; i++) {
      chapters[i].order = i;
    }
    notifyListeners();
  }

  // --- Métier 2 : catalogue, inscription et lecteur de chapitres (étudiant) --

  /// Inscrit l'étudiant courant (`POST /enrollments`)
  void enroll(String courseId) {
    if (isEnrolled(courseId)) return;
    final course = courseById(courseId);
    if (course == null) return;
    _enrollments.add(
      Enrollment(
        courseId: courseId,
        studentId: currentUserId,
        studentName: currentUserName,
        completedChapterIds: [],
        lastAccess: DateTime.now(),
      ),
    );
    course.enrollmentsCount += 1;
    notifyListeners();
  }

  /// Marque un chapitre comme terminé / à refaire
  /// (`PATCH /enrollments/:id/progress` — déclenche les badges L2 côté backend)
  void setChapterCompleted(
    String courseId,
    String chapterId,
    bool completed,
  ) {
    final enrollment = enrollmentFor(courseId);
    if (enrollment == null) return;
    if (completed) {
      if (!enrollment.completedChapterIds.contains(chapterId)) {
        enrollment.completedChapterIds.add(chapterId);
      }
    } else {
      enrollment.completedChapterIds.remove(chapterId);
    }
    enrollment.lastChapterId = chapterId;
    enrollment.lastAccess = DateTime.now();
    notifyListeners();
  }

  /// Prochain chapitre à lire : le premier non terminé, sinon le dernier lu
  Chapter? nextChapterToRead(String courseId) {
    final enrollment = enrollmentFor(courseId);
    final chapters = chaptersOf(courseId);
    if (chapters.isEmpty) return null;
    if (enrollment == null) return chapters.first;
    for (final chapter in chapters) {
      if (!enrollment.completedChapterIds.contains(chapter.id)) {
        return chapter;
      }
    }
    return chapters.last;
  }

  // --- Métier 3 : suivi de progression & tableau de bord enseignant ----------

  int get teacherPublishedCount =>
      teacherCourses.where((c) => c.isPublished).length;

  int get teacherDraftCount =>
      teacherCourses.where((c) => !c.isPublished).length;

  int get teacherEnrollmentsTotal => teacherCourses.fold<int>(
        0,
        (total, course) => total + course.enrollmentsCount,
      );

  /// Progression moyenne sur tous les cours de l'enseignant
  double get teacherAverageProgress {
    final courses = teacherCourses
        .where((c) => enrollmentsOf(c.id).isNotEmpty)
        .toList(growable: false);
    if (courses.isEmpty) return 0;
    return courses.fold<double>(
          0,
          (total, course) => total + courseAverageProgress(course.id),
        ) /
        courses.length;
  }

  /// Chapitres les moins terminés, tous cours confondus (pédagogie ciblée)
  List<ChapterCompletionStat> leastCompletedChapters({int limit = 5}) {
    final stats = <ChapterCompletionStat>[];
    for (final course in teacherCourses) {
      final enrollments = enrollmentsOf(course.id);
      if (enrollments.isEmpty) continue;
      for (final chapter in chaptersOf(course.id)) {
        final completed = enrollments
            .where((e) => e.completedChapterIds.contains(chapter.id))
            .length;
        stats.add(
          ChapterCompletionStat(
            course: course,
            chapter: chapter,
            completedCount: completed,
            enrolledCount: enrollments.length,
          ),
        );
      }
    }
    stats.sort((a, b) => a.rate.compareTo(b.rate));
    return stats.take(limit).toList(growable: false);
  }

  // --- Données de démonstration ---------------------------------------------

  void _seedInitialData() {
    final algo = Course(
      id: 'course_algo_1',
      teacherId: 'teacher_leila',
      teacherName: 'Dr. Leila Mansour',
      teacherVerified: true,
      title: 'Algorithmique & Structures de Données',
      subject: 'Algorithmique',
      level: 'L2',
      description:
          "Cours complet d'algorithmique : complexité, structures de données "
          'linéaires et arborescentes, graphes et tables de hachage. Chaque '
          'chapitre est accompagné d\'exercices corrigés pour préparer les '
          'examens.',
      chaptersCount: 6,
      isPublished: true,
      enrollmentsCount: 4,
      createdAt: DateTime(2026, 9, 15),
    );
    final bdd1 = Course(
      id: 'course_bdd_1',
      teacherId: 'teacher_leila',
      teacherName: 'Dr. Leila Mansour',
      teacherVerified: true,
      title: 'Bases de Données',
      subject: 'Bases de Données',
      level: 'L2',
      description:
          'Modèle relationnel, SQL et normalisation. Le cours se termine par '
          'un TP de conception guidé, à rendre avant la fin du semestre.',
      chaptersCount: 4,
      isPublished: true,
      enrollmentsCount: 2,
      createdAt: DateTime(2026, 9, 20),
    );
    final reseau = Course(
      id: 'course_reseau_1',
      teacherId: 'teacher_leila',
      teacherName: 'Dr. Leila Mansour',
      teacherVerified: true,
      title: 'Réseaux & Sécurité',
      subject: 'Réseaux & Sécurité',
      level: 'L3',
      description:
          "Du modèle OSI aux sous-réseaux CIDR, avec des captures Wireshark "
          'analytiques en TP pour comprendre concrètement les protocoles.',
      chaptersCount: 4,
      isPublished: true,
      enrollmentsCount: 1,
      createdAt: DateTime(2026, 10, 2),
    );
    final bdd2 = Course(
      id: 'course_bdd_2',
      teacherId: 'teacher_leila',
      teacherName: 'Dr. Leila Mansour',
      teacherVerified: true,
      title: 'Bases de Données Relationnelles & SQL Avancé',
      subject: 'Bases de Données',
      level: 'M1',
      description:
          'Approfondissement SQL : transactions, index, plans d\'exécution et '
          'procédures stockées pour les applications à forte charge.',
      chaptersCount: 3,
      isPublished: true,
      enrollmentsCount: 1,
      createdAt: DateTime(2026, 10, 8),
    );
    final ia = Course(
      id: 'course_ia_3',
      teacherId: 'teacher_karim',
      teacherName: 'Pr. Karim Mansouri',
      teacherVerified: true,
      title: 'Machine Learning & Réseaux de Neurones',
      subject: 'Intelligence Artificielle',
      level: 'M2',
      description:
          'Introduction au machine learning puis aux réseaux de neurones : '
          'régression, classification et entraînement sur des datasets réels.',
      chaptersCount: 4,
      isPublished: true,
      enrollmentsCount: 1,
      createdAt: DateTime(2026, 10, 12),
    );
    final flutter = Course(
      id: 'course_flutter_4',
      teacherId: 'user_me',
      teacherName: 'Dr. Leila Mansour',
      teacherVerified: true,
      title: 'Architecture Mobile Cross-Platform (Flutter & NestJS)',
      subject: 'Développement Mobile',
      level: 'M2',
      description:
          "Construire une application mobile complète : Dart, widgets, gestion "
          "d'état avec Provider, puis intégration d'un backend REST NestJS. "
          'Projet fil rouge : EduLink.',
      chaptersCount: 5,
      isPublished: true,
      enrollmentsCount: 3,
      createdAt: DateTime(2026, 10, 15),
    );
    final devweb = Course(
      id: 'course_devweb_5',
      teacherId: 'user_me',
      teacherName: 'Dr. Leila Mansour',
      teacherVerified: true,
      title: 'Développement Web Full-Stack',
      subject: 'Génie Logiciel',
      level: 'L3',
      description:
          'Brouillon en préparation : HTML/CSS modernes puis JavaScript ES6+. '
          'Publication prévue après ajout des chapitres backend.',
      chaptersCount: 2,
      isPublished: false,
      enrollmentsCount: 0,
      createdAt: DateTime(2026, 10, 22),
    );
    _courses.addAll([algo, bdd1, reseau, bdd2, ia, flutter, devweb]);

    Chapter chap(String id, String title, ChapterType type, String? content,
            int durationMin, int order) =>
        Chapter(
          id: id,
          title: title,
          type: type,
          content: content,
          durationMin: durationMin,
          order: order,
        );

    _chaptersByCourse[algo.id] = [
      chap(
        'algo_c1',
        'Complexité & Notations asymptotiques',
        ChapterType.text,
        "Définition du temps d'exécution, notations O, Θ et Ω, analyse du "
        'meilleur et du pire cas, amortissement. Exemples de calcul de '
        'complexité sur les boucles imbriquées et la récursivité.',
        45,
        0,
      ),
      chap(
        'algo_c2',
        'Listes chaînées, Piles & Files',
        ChapterType.text,
        'Implémentation des listes simplement et doublement chaînées, piles '
        "(LIFO) et files (FIFO), applications au parcours et à l'évaluation "
        "d'expressions.",
        40,
        1,
      ),
      chap(
        'algo_c3',
        'Les arbres binaires de recherche',
        ChapterType.text,
        'Insertion, recherche et suppression dans un ABR, parcours préfixe, '
        'infixe et postfixe, équilibrage et arbres AVL.',
        50,
        2,
      ),
      chap(
        'algo_c4',
        'Les graphes : parcours BFS & DFS',
        ChapterType.video,
        'https://www.youtube.com/watch?v=pcKY4hjDrBk',
        35,
        3,
      ),
      chap(
        'algo_c5',
        'Tables de hachage — Fiche de révision',
        ChapterType.pdf,
        'https://cdn.cloudinary.com/edulink/chapters/hachage.pdf',
        30,
        4,
      ),
      chap(
        'algo_c6',
        'Exercices dirigés & corrections (annales)',
        ChapterType.link,
        'https://edulink.example.tn/annales/algo-2025',
        60,
        5,
      ),
    ];

    _chaptersByCourse[bdd1.id] = [
      chap(
        'bdd1_c1',
        'Le modèle relationnel',
        ChapterType.text,
        'Entités, associations, clés primaires et étrangères, passage du '
        "modèle conceptuel au modèle logique, cardinalités.",
        40,
        0,
      ),
      chap(
        'bdd1_c2',
        'SQL : requêtes & jointures',
        ChapterType.pdf,
        'https://cdn.cloudinary.com/edulink/chapters/sql-jointures.pdf',
        45,
        1,
      ),
      chap(
        'bdd1_c3',
        'Normalisation (1NF – 3NF)',
        ChapterType.text,
        'Dépendances fonctionnelles, anomalies de mise à jour, formes '
        'normales et décomposition sans perte.',
        50,
        2,
      ),
      chap(
        'bdd1_c4',
        'TP : conception d\'une base complete',
        ChapterType.video,
        'https://www.youtube.com/watch?v=ztHopE5WwpM',
        40,
        3,
      ),
    ];

    _chaptersByCourse[reseau.id] = [
      chap(
        'res_c1',
        'Le modèle OSI & la pile TCP/IP',
        ChapterType.text,
        'Les 7 couches OSI, encapsulation, correspondance avec TCP/IP, '
        'rôles des protocoles ARP, IP, TCP et UDP.',
        40,
        0,
      ),
      chap(
        'res_c2',
        'Configuration des routeurs (démo)',
        ChapterType.video,
        'https://www.youtube.com/watch?v=CYi-b8cI3eU',
        45,
        1,
      ),
      chap(
        'res_c3',
        'Sous-réseaux & notation CIDR',
        ChapterType.text,
        'Masques de sous-réseau, calcul du nombre d\'hôtes, découpage en '
        'sous-réseaux, tableaux de correspondance CIDR.',
        35,
        2,
      ),
      chap(
        'res_c4',
        'TP : analyse de trames avec Wireshark',
        ChapterType.pdf,
        'https://cdn.cloudinary.com/edulink/chapters/tp-wireshark.pdf',
        30,
        3,
      ),
    ];

    _chaptersByCourse[bdd2.id] = [
      chap(
        'bdd2_c1',
        'Transactions & concurrence d\'accès',
        ChapterType.text,
        'Propriétés ACID, niveaux d\'isolation, verrous partagés et exclusifs, '
        'interblocages et stratégies de reprise.',
        50,
        0,
      ),
      chap(
        'bdd2_c2',
        'Index & plans d\'exécution',
        ChapterType.pdf,
        'https://cdn.cloudinary.com/edulink/chapters/index-sql.pdf',
        40,
        1,
      ),
      chap(
        'bdd2_c3',
        'Procédures stockées & déclencheurs',
        ChapterType.text,
        'Écriture de procédures, gestion des erreurs, triggers BEFORE/AFTER '
        'et cas d\'usage en production.',
        45,
        2,
      ),
    ];

    _chaptersByCourse[ia.id] = [
      chap(
        'ia_c1',
        'Introduction au machine learning',
        ChapterType.text,
        "Apprentissage supervisé et non supervisé, découpage train/test, "
        "notions d'overfitting et de généralisation.",
        40,
        0,
      ),
      chap(
        'ia_c2',
        'Régression & classification',
        ChapterType.text,
        'Régression linéaire et logistique, arbres de décision, matrices de '
        'confusion et métriques (précision, rappel, F1).',
        45,
        1,
      ),
      chap(
        'ia_c3',
        'Réseaux de neurones : architecture',
        ChapterType.video,
        'https://www.youtube.com/watch?v=aircAruvnKk',
        50,
        2,
      ),
      chap(
        'ia_c4',
        'Datasets d\'entraînement (Kaggle)',
        ChapterType.link,
        'https://www.kaggle.com/datasets',
        30,
        3,
      ),
    ];

    _chaptersByCourse[flutter.id] = [
      chap(
        'fl_c1',
        'Dart : syntaxe & null safety',
        ChapterType.text,
        'Types, collections, fonctions de premier ordre, null safety et '
        'opérateurs ?? et ?., programmation asynchrone Future/async.',
        40,
        0,
      ),
      chap(
        'fl_c2',
        'Widgets stateless & stateful',
        ChapterType.text,
        'Arbre de widgets, contraintes de layout, StatefulWidget et cycle de '
        'vie, clés et rebuilds.',
        45,
        1,
      ),
      chap(
        'fl_c3',
        "Provider & gestion d'état",
        ChapterType.video,
        'https://www.youtube.com/watch?v=l3S5-26XQSQ',
        40,
        2,
      ),
      chap(
        'fl_c4',
        'TP : application EduLink',
        ChapterType.pdf,
        'https://cdn.cloudinary.com/edulink/chapters/tp-edulink.pdf',
        60,
        3,
      ),
      chap(
        'fl_c5',
        'Intégration REST avec un backend NestJS',
        ChapterType.text,
        'Modélisation des appels HTTP, sérialisation JSON, gestion des '
        'erreurs et intercepteurs, jetons Firebase.',
        50,
        4,
      ),
    ];

    _chaptersByCourse[devweb.id] = [
      chap(
        'dw_c1',
        'HTML & CSS modernes',
        ChapterType.text,
        'Sémantique HTML5, Flexbox et Grid, variables CSS et responsive '
        'design.',
        40,
        0,
      ),
      chap(
        'dw_c2',
        'JavaScript ES6+',
        ChapterType.text,
        'let/const, fonctions fléchées, déstructuration, modules, promesses '
        'et async/await.',
        45,
        1,
      ),
    ];

    // Inscriptions de démonstration (id Firestore = courseId_studentId)
    Enrollment enr(String courseId, String studentId, String studentName,
            List<String> completed, String? lastChapterId) =>
        Enrollment(
          courseId: courseId,
          studentId: studentId,
          studentName: studentName,
          completedChapterIds: completed,
          lastChapterId: lastChapterId,
          lastAccess: DateTime(2026, 10, 24),
        );

    _enrollments.addAll([
      // Algorithmique (4 inscrits)
      enr('course_algo_1', 'user_me', 'Yasmine Ben Ali',
          ['algo_c1', 'algo_c2', 'algo_c3'], 'algo_c3'),
      enr('course_algo_1', 'student_sara', 'Sara Gharbi',
          ['algo_c1', 'algo_c2', 'algo_c3', 'algo_c4', 'algo_c5', 'algo_c6'],
          'algo_c6'),
      enr('course_algo_1', 'student_mehdi', 'Mehdi Jelassi',
          ['algo_c1', 'algo_c2'], 'algo_c2'),
      enr('course_algo_1', 'student_rania', 'Rania Khelifi',
          ['algo_c1', 'algo_c3', 'algo_c4', 'algo_c5'], 'algo_c5'),
      // Bases de Données L2 (2 inscrits)
      enr('course_bdd_1', 'user_me', 'Yasmine Ben Ali', ['bdd1_c1'], 'bdd1_c1'),
      enr('course_bdd_1', 'student_sara', 'Sara Gharbi',
          ['bdd1_c1', 'bdd1_c2', 'bdd1_c3'], 'bdd1_c3'),
      // SQL Avancé M1 (1 inscrit)
      enr('course_bdd_2', 'student_mehdi', 'Mehdi Jelassi', [], null),
      // Réseaux & Sécurité (1 inscrit)
      enr('course_reseau_1', 'student_rania', 'Rania Khelifi',
          ['res_c1', 'res_c2'], 'res_c2'),
      // Machine Learning (1 inscrit)
      enr('course_ia_3', 'student_sara', 'Sara Gharbi', ['ia_c1'], 'ia_c1'),
      // Flutter & NestJS (3 inscrits)
      enr('course_flutter_4', 'user_me', 'Yasmine Ben Ali', [], null),
      enr('course_flutter_4', 'student_mehdi', 'Mehdi Jelassi',
          ['fl_c1', 'fl_c2', 'fl_c3'], 'fl_c3'),
      enr('course_flutter_4', 'student_sara', 'Sara Gharbi',
          ['fl_c1', 'fl_c2', 'fl_c3', 'fl_c4'], 'fl_c4'),
    ]);
  }
}
