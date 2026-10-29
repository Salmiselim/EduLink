import 'package:flutter/material.dart';
import '../data/courses_mock_data.dart';
import '../models/courses_models.dart';
import '../widgets/chapter_edit_sheet.dart';
import '../widgets/chapter_tile.dart';
import '../widgets/courses_ui.dart';

// ============================================================================
// GESTION D'UN COURS — VUE ENSEIGNANT (CourseManageScreen)
// ROUTE POUSSÉE — ouverte depuis « Options du cours » ou la page du cours.
// Réunit les statistiques du cours, la gestion des chapitres (ajout,
// modification, suppression et réordonnancement) et le suivi des inscrits
// avec leur progression individuelle (Métier 3).
// ============================================================================

class CourseManageScreen extends StatefulWidget {
  final String courseId;

  const CourseManageScreen({super.key, required this.courseId});

  @override
  State<CourseManageScreen> createState() => _CourseManageScreenState();
}

class _CourseManageScreenState extends State<CourseManageScreen> {
  final CoursesController _controller = CoursesController.instance;

  // --- Actions ----------------------------------------------------------------

  /// Publie ou masque le cours (`PATCH /courses/:id/publish`).
  /// La publication est refusée (`false`) tant que le cours n'a aucun chapitre.
  void _togglePublish(Course course) {
    final wasPublished = course.isPublished;
    final ok = _controller.setPublished(course.id, !wasPublished);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(
          ok
              ? (wasPublished
                    ? 'Cours masqué du catalogue.'
                    : 'Cours publié dans le catalogue !')
              : 'Ajoutez au moins un chapitre avant de publier.',
        ),
      ),
    );
  }

  /// Feuille d'actions sur un chapitre (modifier / supprimer)
  void _openChapterActionsSheet(Course course, Chapter chapter) {
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
                Text(
                  chapter.title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: CourseColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.edit_rounded,
                    color: CourseColors.primary,
                  ),
                  title: const Text('Modifier le chapitre'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ChapterEditSheet.open(
                      context,
                      courseId: course.id,
                      existing: chapter,
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.delete_rounded,
                    color: CourseColors.danger,
                  ),
                  title: const Text(
                    'Supprimer le chapitre',
                    style: TextStyle(color: CourseColors.danger),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _controller.deleteChapter(course.id, chapter.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        duration: Duration(seconds: 2),
                        content: Text('Chapitre supprimé.'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Feuille de détail d'un étudiant inscrit : anneau de progression, dernier
  /// accès et lecture seule des chapitres (cochés s'ils sont terminés)
  void _openStudentSheet(Course course, Enrollment enrollment) {
    final progress = _controller.progressOf(enrollment);
    final chapters = _controller.chaptersOf(course.id);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
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
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: CourseColors.infoBg,
                      child: Text(
                        _initials(enrollment.studentName),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: CourseColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        enrollment.studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: CourseColors.text,
                        ),
                      ),
                    ),
                    ProgressRing(value: progress),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: CourseColors.neutralBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InfoRow(
                    icon: Icons.schedule_rounded,
                    label: 'Dernier accès',
                    value: _formatDate(enrollment.lastAccess),
                  ),
                ),
                const SizedBox(height: 14),
                SectionHeader(title: 'Chapitres', count: chapters.length),
                if (chapters.isEmpty)
                  const Text(
                    'Aucun chapitre dans ce cours.',
                    style: TextStyle(fontSize: 12.5, color: CourseColors.muted),
                  )
                else
                  for (var i = 0; i < chapters.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ChapterTile(
                        chapter: chapters[i],
                        number: i + 1,
                        completed: enrollment.completedChapterIds.contains(
                          chapters[i].id,
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

  // --- Helpers d'affichage ------------------------------------------------------

  /// Formate une date au format jour/mois/année (ex. 24/10/2026)
  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  /// Initiales d'un nom complet pour l'avatar (ex. « Yasmine Ben Ali » → « YA »)
  String _initials(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  // --- Construction de l'interface ------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final course = _controller.courseById(widget.courseId);
        if (course == null) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
            ),
            body: const EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Cours introuvable',
              message: 'Ce cours a peut-être été supprimé.',
            ),
          );
        }

        return Scaffold(
          backgroundColor: CourseColors.scaffold,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            title: Text(
              course.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: CourseColors.text,
              ),
            ),
            actions: [
              IconButton(
                tooltip: course.isPublished
                    ? 'Masquer le cours'
                    : 'Publier le cours',
                onPressed: () => _togglePublish(course),
                icon: Icon(
                  course.isPublished
                      ? Icons.visibility_off_rounded
                      : Icons.publish_rounded,
                  color: course.isPublished
                      ? CourseColors.warning
                      : CourseColors.success,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatRow(course),
              const SizedBox(height: 20),
              _buildChaptersSection(course),
              const SizedBox(height: 20),
              _buildStudentsSection(course),
            ],
          ),
        );
      },
    );
  }

  /// Rangée de statistiques : inscrits, progression moyenne et chapitres
  Widget _buildStatRow(Course course) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            icon: Icons.group_outlined,
            value: '${course.enrollmentsCount}',
            label: 'Inscrits',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            icon: Icons.insights_rounded,
            value:
                '${(_controller.courseAverageProgress(course.id) * 100).round()}%',
            label: 'Progression moy.',
            color: CourseColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            icon: Icons.menu_book_rounded,
            value: '${course.chaptersCount}',
            label: 'Chapitres',
            color: CourseColors.primaryDark,
          ),
        ),
      ],
    );
  }

  /// Section chapitres : ajout, réordonnancement par glisser-déposer et
  /// actions secondaires (modifier / supprimer) via la poignée ⋮
  Widget _buildChaptersSection(Course course) {
    final chapters = _controller.chaptersOf(course.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Chapitres',
          count: chapters.length,
          trailing: TextButton.icon(
            onPressed: () =>
                ChapterEditSheet.open(context, courseId: course.id),
            style: TextButton.styleFrom(
              foregroundColor: CourseColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Ajouter'),
          ),
        ),
        if (chapters.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: courseCardDecoration(),
            child: const Text(
              "Aucun chapitre pour l'instant. Utilisez « Ajouter » pour créer "
              'le premier contenu du cours.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: CourseColors.muted,
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: chapters.length,
            onReorderItem: (oldIndex, newIndex) =>
                _controller.reorderChapters(course.id, oldIndex, newIndex),
            itemBuilder: (context, i) {
              final chapter = chapters[i];
              return Padding(
                key: ValueKey(chapter.id),
                padding: const EdgeInsets.only(bottom: 8),
                child: ChapterTile(
                  chapter: chapter,
                  number: i + 1,
                  onTap: () => ChapterEditSheet.open(
                    context,
                    courseId: course.id,
                    existing: chapter,
                  ),
                  trailingOverride: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: const Icon(
                          Icons.drag_indicator_rounded,
                          color: CourseColors.muted,
                          size: 20,
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            _openChapterActionsSheet(course, chapter),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: CourseColors.muted,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  /// Section inscrits : progression individuelle de chaque étudiant, avec
  /// une feuille de détail au toucher (anneau, dernier accès, chapitres)
  Widget _buildStudentsSection(Course course) {
    final enrollments = _controller.enrollmentsOf(course.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Inscrits', count: enrollments.length),
        if (enrollments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              "Aucun étudiant inscrit pour le moment. Les inscriptions "
              'apparaîtront ici avec leur progression.',
              style: TextStyle(fontSize: 12.5, color: CourseColors.muted),
            ),
          )
        else
          ...enrollments.map((enrollment) {
            final progress = _controller.progressOf(enrollment);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _openStudentSheet(course, enrollment),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: courseCardDecoration(),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: CourseColors.infoBg,
                          child: Text(
                            _initials(enrollment.studentName),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: CourseColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                enrollment.studentName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: CourseColors.text,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ProgressBar(value: progress),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${(progress * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: CourseColors.text,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: CourseColors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
