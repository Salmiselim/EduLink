import 'package:flutter/material.dart';
import '../data/courses_mock_data.dart';
import '../models/courses_models.dart';
import '../routes/courses_routes.dart';
import '../widgets/course_card.dart';
import '../widgets/courses_ui.dart';

// ============================================================================
// ÉCRAN PRINCIPAL DE L'ONGLET COURS (CoursesScreen)
// Page 5 du Plan d'équipe — Section Flutter :
// « onglet Cours (vue enseignant : mes cours + assistant ; vue étudiant :
// mes cours + catalogue), lecteur de chapitres en route poussée ».
// La vue enseignant ajoute le tableau de bord de progression (Métier 3).
// ============================================================================

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final CoursesController _controller = CoursesController.instance;
  final TextEditingController _searchController = TextEditingController();

  /// Bascule principale : 0 = Mes cours · 1 = Catalogue (étudiant) ou
  /// Statistiques (enseignant)
  int _section = 0;

  // --- État des filtres du catalogue (Métier 2) ---
  String? _filterSubject;
  String? _filterLevel;
  String _sortBy = 'recent'; // recent | popular | title

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_filterSubject != null) count++;
    if (_filterLevel != null) count++;
    return count;
  }

  /// Filtre et trie le catalogue public
  /// Endpoint simulé : `GET /courses?subject=&level=&q=`
  List<Course> _getFilteredCatalogCourses() {
    final query = _searchController.text.trim().toLowerCase();
    final list = _controller.publishedCourses.where((course) {
      if (_filterSubject != null && course.subject != _filterSubject) {
        return false;
      }
      if (_filterLevel != null && course.level != _filterLevel) return false;
      if (query.isNotEmpty) {
        final matchTitle = course.title.toLowerCase().contains(query);
        final matchDesc = course.description.toLowerCase().contains(query);
        final matchSubject = course.subject.toLowerCase().contains(query);
        final matchTeacher = course.teacherName.toLowerCase().contains(query);
        if (!matchTitle && !matchDesc && !matchSubject && !matchTeacher) {
          return false;
        }
      }
      return true;
    }).toList();

    switch (_sortBy) {
      case 'popular':
        list.sort((a, b) => b.enrollmentsCount.compareTo(a.enrollmentsCount));
        break;
      case 'title':
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      default:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  /// Recommandations d'après les matières des cours déjà suivis :
  /// ici les cours suggérés partagent une matière avec un cours suivi)
  List<Course> _getRecommendedCourses() {
    final followedSubjects =
        _controller.enrolledCourses.map((c) => c.subject).toSet();
    return _controller.publishedCourses.where((course) {
      if (_controller.isEnrolled(course.id)) return false;
      return followedSubjects.contains(course.subject);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isTeacher = _controller.isTeacher;

        return Column(
          children: [
            // Bascule principale de l'onglet Cours (SegmentedButton — M3)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: isTeacher
                    ? const [
                        ButtonSegment(
                          value: 0,
                          label: Text('Mes cours'),
                          icon: Icon(Icons.collections_bookmark_outlined),
                        ),
                        ButtonSegment(
                          value: 1,
                          label: Text('Statistiques'),
                          icon: Icon(Icons.insights_outlined),
                        ),
                      ]
                    : const [
                        ButtonSegment(
                          value: 0,
                          label: Text('Mes cours'),
                          icon: Icon(Icons.collections_bookmark_outlined),
                        ),
                        ButtonSegment(
                          value: 1,
                          label: Text('Catalogue'),
                          icon: Icon(Icons.travel_explore_outlined),
                        ),
                      ],
                selected: {_section},
                onSelectionChanged: (selection) =>
                    setState(() => _section = selection.first),
              ),
            ),
            Expanded(
              child: isTeacher
                  ? (_section == 0
                      ? _buildTeacherCourses()
                      : _buildTeacherStats())
                  : (_section == 0
                      ? _buildStudentCourses()
                      : _buildCatalog()),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // VUE ÉTUDIANT — « Mes cours » (inscriptions & reprise de lecture)
  // ===========================================================================

  Widget _buildStudentCourses() {
    final enrollments = _controller.myEnrollments;
    if (enrollments.isEmpty) {
      return EmptyState(
        icon: Icons.collections_bookmark_outlined,
        title: 'Aucun cours suivi',
        message:
            "Explorez le catalogue et inscrivez-vous à votre premier cours "
            'pour suivre votre progression chapitre par chapitre.',
        actionLabel: 'Explorer le catalogue',
        onAction: () => setState(() => _section = 1),
      );
    }

    final inProgress = enrollments
        .where((e) =>
            e.lastChapterId != null &&
            _controller.progressOf(e) < 1)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (inProgress.isNotEmpty) ...[
          const SectionHeader(title: 'Continuer la lecture'),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: inProgress.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) =>
                  _ContinueCard(enrollment: inProgress[index]),
            ),
          ),
          const SizedBox(height: 20),
        ],
        SectionHeader(title: 'Mes cours', count: enrollments.length),
        ...enrollments.map((enrollment) {
          final course = _controller.courseById(enrollment.courseId);
          if (course == null) return const SizedBox.shrink();
          final next = _controller.nextChapterToRead(course.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CourseCard(
              course: course,
              enrolled: true,
              progress: _controller.progressOf(enrollment),
              continueLabel: next == null
                  ? 'Cours terminé — félicitations !'
                  : 'À suivre : ${next.title}',
              onTap: () => _openCourse(course.id),
            ),
          );
        }),
      ],
    );
  }

  // ===========================================================================
  // VUE ÉTUDIANT — « Catalogue » (recherche, filtres, recommandations)
  // ===========================================================================

  Widget _buildCatalog() {
    final results = _getFilteredCatalogCourses();
    final recommendations =
        (_activeFiltersCount == 0 && _searchController.text.trim().isEmpty)
            ? _getRecommendedCourses()
            : const <Course>[];

    return Column(
      children: [
        // Recherche instantanée + puces matières + filtres & tri
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: courseInputDecoration(
                  label: 'Rechercher un cours...',
                  hint: 'Titre, matière, enseignant',
                  icon: Icons.search_rounded,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: CoursesController.subjects.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final subject = index == 0
                        ? null
                        : CoursesController.subjects[index - 1];
                    final label = subject ?? 'Toutes';
                    return ChoiceChip(
                      label: Text(label),
                      selected: _filterSubject == subject,
                      selectedColor: CourseColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _filterSubject == subject
                            ? Colors.white
                            : CourseColors.textSecondary,
                      ),
                      showCheckmark: false,
                      onSelected: (_) =>
                          setState(() => _filterSubject = subject),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Badge(
                    isLabelVisible: _activeFiltersCount > 0,
                    label: Text('$_activeFiltersCount'),
                    backgroundColor: CourseColors.primary,
                    child: OutlinedButton.icon(
                      onPressed: _openFiltersSheet,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CourseColors.text,
                        side: const BorderSide(color: CourseColors.border),
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text(
                        'Filtres & tri',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${results.length} cours',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: CourseColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Aucun cours trouvé',
                  message:
                      'Essayez d\'élargir vos filtres ou de modifier votre '
                  'recherche pour découvrir plus de cours.',
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (recommendations.isNotEmpty) ...[
                      const SectionHeader(title: 'Recommandés pour toi'),
                      SizedBox(
                        height: 150,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: recommendations.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) => SizedBox(
                            width: 300,
                            child: CourseCard(
                              course: recommendations[index],
                              onTap: () =>
                                  _openCourse(recommendations[index].id),
                              onEnroll: () =>
                                  _openEnrollSheet(recommendations[index]),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    SectionHeader(
                      title: recommendations.isEmpty ? 'Catalogue' : 'Tous les cours',
                      count: results.length,
                    ),
                    ...results.map((course) {
                      final enrolled = _controller.isEnrolled(course.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CourseCard(
                          course: course,
                          enrolled: enrolled,
                          progress: enrolled
                              ? _controller.progressOf(
                                  _controller.enrollmentFor(course.id)!)
                              : null,
                          onTap: () => _openCourse(course.id),
                          onEnroll:
                              enrolled ? null : () => _openEnrollSheet(course),
                        ),
                      );
                    }),
                  ],
                ),
        ),
      ],
    );
  }

  // ===========================================================================
  // VUE ENSEIGNANT — « Mes cours » (CRUD + publication)
  // ===========================================================================

  Widget _buildTeacherCourses() {
    final courses = _controller.teacherCourses;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.check_circle_outline_rounded,
                value: '${_controller.teacherPublishedCount}',
                label: 'Publiés',
                color: CourseColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                icon: Icons.edit_note_rounded,
                value: '${_controller.teacherDraftCount}',
                label: 'Brouillons',
                color: CourseColors.warning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                icon: Icons.group_outlined,
                value: '${_controller.teacherEnrollmentsTotal}',
                label: 'Inscrits',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SectionHeader(title: 'Mes cours', count: courses.length),
        if (courses.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              "Créez votre premier cours avec l'assistant (+) : infos, "
              'chapitres, aperçu puis publication.',
              style: TextStyle(fontSize: 12.5, color: CourseColors.muted),
            ),
          ),
        ...courses.map(
          (course) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CourseCard(
              course: course,
              isTeacherVariant: true,
              onTap: () => _openCourse(course.id),
              onMore: () => _openCourseOptionsSheet(course),
            ),
          ),
        ),
      ],
    );
  }

  /// Feuille coulissante « Options du cours » (modifier, gérer, publier,
  /// supprimer) — les actions secondaires vivent dans des bottom sheets.
  void _openCourseOptionsSheet(Course course) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: CourseColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        course.title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: CourseColors.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    CourseStatusBadge(isPublished: course.isPublished),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.edit_rounded,
                      color: CourseColors.primary),
                  title: const Text('Modifier le cours'),
                  subtitle: const Text('Infos & chapitres (assistant)'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.pushNamed(
                      context,
                      CoursesRoutes.courseWizard,
                      arguments: CourseWizardArgs(existingCourse: course),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.tune_rounded,
                      color: CourseColors.textSecondary),
                  title: const Text('Gérer chapitres & inscrits'),
                  subtitle: const Text('Réordonner, suivre la progression'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.pushNamed(
                      context,
                      CoursesRoutes.courseManage,
                      arguments: CourseManageArgs(courseId: course.id),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    course.isPublished
                        ? Icons.visibility_off_rounded
                        : Icons.publish_rounded,
                    color: course.isPublished
                        ? CourseColors.warning
                        : CourseColors.success,
                  ),
                  title: Text(
                    course.isPublished
                        ? 'Masquer le cours'
                        : 'Publier le cours',
                  ),
                  subtitle: Text(
                    course.isPublished
                        ? 'Retirer du catalogue public'
                        : 'Rendre visible dans le catalogue',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    final ok = _controller.setPublished(
                      course.id,
                      !course.isPublished,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 2),
                        content: Text(
                          ok
                              ? (course.isPublished
                                  ? 'Cours masqué du catalogue.'
                                  : 'Cours publié dans le catalogue !')
                              : 'Ajoutez au moins un chapitre avant de publier.',
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 8),
                ListTile(
                  leading: const Icon(Icons.delete_rounded,
                      color: CourseColors.danger),
                  title: const Text(
                    'Supprimer le cours',
                    style: TextStyle(color: CourseColors.danger),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmDeleteCourse(course);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Boîte de dialogue de confirmation avant suppression (critère 5)
  void _confirmDeleteCourse(Course course) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Supprimer ce cours ?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        content: Text(
          '« ${course.title} », ses chapitres et les inscriptions associées '
          'seront définitivement supprimés.',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _controller.deleteCourse(course.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cours supprimé.')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: CourseColors.danger,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // VUE ENSEIGNANT — « Statistiques » (tableau de bord — Métier 3)
  // ===========================================================================

  Widget _buildTeacherStats() {
    final leastCompleted = _controller.leastCompletedChapters(limit: 5);
    final coursesWithStudents = _controller.teacherCourses
        .where((c) => _controller.enrollmentsOf(c.id).isNotEmpty)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.group_outlined,
                value: '${_controller.teacherEnrollmentsTotal}',
                label: 'Inscrits totaux',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                icon: Icons.insights_rounded,
                value:
                    '${(_controller.teacherAverageProgress * 100).round()}%',
                label: 'Progression moy.',
                color: CourseColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                icon: Icons.menu_book_rounded,
                value:
                    '${_controller.teacherCourses.fold<int>(0, (t, c) => t + c.chaptersCount)}',
                label: 'Chapitres',
                color: CourseColors.primaryDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Chapitres les moins terminés'),
        Text(
          'Repérez où vos étudiants décrochent pour améliorer le contenu.',
          style: const TextStyle(fontSize: 11.5, color: CourseColors.muted),
        ),
        const SizedBox(height: 10),
        if (leastCompleted.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              "Aucune statistique pour l'instant : vos cours n'ont pas encore "
              "d'inscrits.",
              style: TextStyle(fontSize: 12.5, color: CourseColors.muted),
            ),
          )
        else
          ...leastCompleted.map((stat) => _ChapterStatCard(stat: stat)),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Progression par cours'),
        if (coursesWithStudents.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Aucun inscrit pour le moment.',
              style: TextStyle(fontSize: 12.5, color: CourseColors.muted),
            ),
          )
        else
          ...coursesWithStudents.map((course) {
            final progress = _controller.courseAverageProgress(course.id);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: courseCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          course.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: CourseColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: progress >= 0.7
                              ? CourseColors.success
                              : (progress >= 0.4
                                  ? CourseColors.warning
                                  : CourseColors.danger),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ProgressBar(value: progress),
                  const SizedBox(height: 6),
                  Text(
                    '${course.enrollmentsCount} inscrits · '
                    '${course.chaptersCount} chapitres',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: CourseColors.muted,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ===========================================================================
  // Actions partagées : navigation, inscription, feuilles coulissantes
  // ===========================================================================

  void _openCourse(String courseId) {
    Navigator.pushNamed(
      context,
      CoursesRoutes.courseDetail,
      arguments: CourseDetailArgs(courseId: courseId),
    );
  }

  /// Feuille de confirmation d'inscription (`POST /enrollments`)
  void _openEnrollSheet(Course course) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: CourseColors.infoBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: CourseColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Rejoindre ce cours ?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: CourseColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CourseColors.neutralBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      InfoRow(
                        icon: Icons.menu_book_outlined,
                        label: 'Cours',
                        value: course.title,
                      ),
                      InfoRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Enseignant',
                        value: course.teacherName,
                      ),
                      InfoRow(
                        icon: Icons.format_list_numbered_rounded,
                        label: 'Chapitres',
                        value:
                            '${course.chaptersCount} · ${_controller.totalDurationMin(course.id)} min',
                      ),
                      InfoRow(
                        icon: Icons.school_outlined,
                        label: 'Niveau',
                        value: course.level,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _controller.enroll(course.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 2),
                          content: Text(
                            'Inscrit à « ${course.title} » — bon courage !',
                          ),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: CourseColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Confirmer l'inscription",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Feuille coulissante « Filtres & tri » du catalogue
  void _openFiltersSheet() {
    String? subject = _filterSubject;
    String? level = _filterLevel;
    String sort = _sortBy;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: CourseColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Text(
                          'Filtres & tri',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: CourseColors.text,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded,
                              color: CourseColors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Matière',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: CourseColors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in ['Toutes', ...CoursesController.subjects])
                          ChoiceChip(
                            label: Text(s),
                            selected: s == 'Toutes'
                                ? subject == null
                                : subject == s,
                            selectedColor: CourseColors.primary,
                            labelStyle: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: (s == 'Toutes' && subject == null) ||
                                      subject == s
                                  ? Colors.white
                                  : CourseColors.textSecondary,
                            ),
                            showCheckmark: false,
                            onSelected: (_) => setSheetState(
                              () => subject = s == 'Toutes' ? null : s,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Niveau',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: CourseColors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final l in ['Tous', ...CoursesController.levels])
                          ChoiceChip(
                            label: Text(l),
                            selected:
                                l == 'Tous' ? level == null : level == l,
                            selectedColor: CourseColors.primary,
                            labelStyle: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: (l == 'Tous' && level == null) ||
                                      level == l
                                  ? Colors.white
                                  : CourseColors.textSecondary,
                            ),
                            showCheckmark: false,
                            onSelected: (_) =>
                                setSheetState(() => level = l == 'Tous' ? null : l),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Trier par',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: CourseColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: 'recent',
                            label: Text('Récent'),
                            icon: Icon(Icons.schedule_outlined, size: 16),
                          ),
                          ButtonSegment(
                            value: 'popular',
                            label: Text('Populaire'),
                            icon: Icon(Icons.local_fire_department_outlined,
                                size: 16),
                          ),
                          ButtonSegment(
                            value: 'title',
                            label: Text('A–Z'),
                            icon: Icon(Icons.sort_by_alpha_outlined, size: 16),
                          ),
                        ],
                        selected: {sort},
                        onSelectionChanged: (selection) =>
                            setSheetState(() => sort = selection.first),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                subject = null;
                                level = null;
                                sort = 'recent';
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: CourseColors.textSecondary,
                              side:
                                  const BorderSide(color: CourseColors.border),
                              minimumSize: const Size(0, 46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Réinitialiser',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              setState(() {
                                _filterSubject = subject;
                                _filterLevel = level;
                                _sortBy = sort;
                              });
                              Navigator.pop(sheetContext);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: CourseColors.primary,
                              minimumSize: const Size(0, 46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Appliquer',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================================================
// WIDGETS PRIVÉS DE L'ÉCRAN
// ============================================================================

/// Carte horizontale « Continuer la lecture » (reprise là où l'on s'est arrêté)
class _ContinueCard extends StatelessWidget {
  final Enrollment enrollment;

  const _ContinueCard({required this.enrollment});

  @override
  Widget build(BuildContext context) {
    final controller = CoursesController.instance;
    final course = controller.courseById(enrollment.courseId);
    if (course == null) return const SizedBox.shrink();

    final progress = controller.progressOf(enrollment);
    final lastChapter = controller
        .chaptersOf(course.id)
        .where((c) => c.id == enrollment.lastChapterId)
        .firstOrNull;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          final target = lastChapter ??
              controller.nextChapterToRead(course.id) ??
              (controller.chaptersOf(course.id).isEmpty
                  ? null
                  : controller.chaptersOf(course.id).first);
          if (target == null) return;
          Navigator.pushNamed(
            context,
            CoursesRoutes.chapterReader,
            arguments: ChapterReaderArgs(
              courseId: course.id,
              chapterId: target.id,
            ),
          );
        },
        child: Container(
          width: 250,
          padding: const EdgeInsets.all(12),
          decoration: courseCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [CourseColors.primary, CourseColors.primaryDark],
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: const Icon(
                      Icons.play_circle_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: CourseColors.text,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              ProgressBar(value: progress),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lastChapter == null
                          ? 'Reprendre la lecture'
                          : 'Reprendre : ${lastChapter.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: CourseColors.primary,
                      ),
                    ),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: CourseColors.text,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte « chapitre le moins terminé » du tableau de bord enseignant
class _ChapterStatCard extends StatelessWidget {
  final ChapterCompletionStat stat;

  const _ChapterStatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    final rate = stat.rate;
    final percent = (rate * 100).round();
    final color = percent < 40
        ? CourseColors.danger
        : (percent < 70 ? CourseColors.warning : CourseColors.success);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: courseCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: stat.chapter.type.background,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  stat.chapter.type.icon,
                  size: 15,
                  color: stat.chapter.type.color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.chapter.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: CourseColors.text,
                      ),
                    ),
                    Text(
                      '${stat.course.title} · ${stat.completedCount}/${stat.enrolledCount} étudiants',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: CourseColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ProgressBar(value: rate, color: color),
        ],
      ),
    );
  }
}
