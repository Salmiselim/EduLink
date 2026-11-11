import 'package:flutter/material.dart';
import '../data/courses_mock_data.dart';
import '../models/courses_models.dart';
import '../services/courses_ai_service.dart';
import '../widgets/chapter_edit_sheet.dart';
import '../widgets/chapter_tile.dart';
import '../widgets/courses_ui.dart';

// Écran d'administration d'un cours côté enseignant (`CourseManageScreen`).
// Centralise les indicateurs clés du cours, l'édition et le réordonnancement des
// chapitres par glisser-déposer (`ReorderableListView.builder`) ainsi que le suivi
// individuel de progression des étudiants inscrits.

/// Tableau de gestion d'un cours ouvert via la route nommée `CoursesRoutes.courseManage`.
class CourseManageScreen extends StatefulWidget {
  final String courseId;

  const CourseManageScreen({super.key, required this.courseId});

  @override
  State<CourseManageScreen> createState() => _CourseManageScreenState();
}

class _CourseManageScreenState extends State<CourseManageScreen> {
  final CoursesController _controller = CoursesController.instance;

  // Actions de gestion sur le cours, ses chapitres et ses inscrits.

  /// Bascule la publication du cours via `CoursesController.setPublished` et affiche
  /// un retour `SnackBar` (bloque la publication tant qu'aucun chapitre n'existe).
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

  // ── Traduction du cours assistée par IA (couche Service) ─────────────────

  /// Choisit les langues cibles puis traduit la description et tous les
  /// chapitres texte du cours en UNE SEULE requête par langue (économie de
  /// quota — chaque modèle gratuit n'accepte que 20 requêtes par jour) ;
  /// les traductions sont enregistrées dans Firestore et deviennent
  /// disponibles pour tous les étudiants.
  Future<void> _translateCourse(Course course) async {
    final languages = await _pickTranslationLanguages();
    if (languages.isEmpty || !mounted) return;

    final textChapters = _controller
        .chaptersOf(course.id)
        .where(
          (c) =>
              c.type == ChapterType.text &&
              (c.content ?? '').trim().isNotEmpty,
        )
        .toList();

    final progress = ValueNotifier<int>(0);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: ValueListenableBuilder<int>(
          valueListenable: progress,
          builder: (context, done, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.translate_rounded,
                color: Color(0xFF7C3AED),
                size: 28,
              ),
              const SizedBox(height: 10),
              const Text(
                'Traduction du cours en cours…',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: languages.isEmpty ? null : done / languages.length,
                color: CourseColors.primary,
                backgroundColor: CourseColors.neutralBg,
              ),
              const SizedBox(height: 8),
              Text(
                'Langues traduites : $done / ${languages.length}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: CourseColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    var translatedLanguages = 0;
    try {
      for (final language in languages) {
        final bundle = await CoursesAiService.instance.translateCourseBundle(
          description: course.description,
          items: {
            for (final chapter in textChapters)
              chapter.id: (chapter.content ?? '').trim(),
          },
          language: language,
          courseTitle: course.title,
        );
        if (bundle == null) {
          throw AiUnavailableException(
            'Traduction ${language.label} indisponible — réessaie plus tard.',
          );
        }
        final translatedDescription = bundle['description'];
        if (translatedDescription != null &&
            translatedDescription.trim().isNotEmpty) {
          _controller.saveCourseDescriptionTranslation(
            course.id,
            language.code,
            translatedDescription,
          );
        }
        for (final chapter in textChapters) {
          final translated = bundle[chapter.id];
          if (translated != null && translated.trim().isNotEmpty) {
            _controller.saveChapterTranslation(
              course.id,
              chapter.id,
              language.code,
              translated,
            );
          }
        }
        progress.value = ++translatedLanguages;
      }
    } on AiUnavailableException catch (error) {
      progress.dispose();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Text(error.message),
        ),
      );
      return;
    }
    progress.dispose();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(
          'Traduction terminée : ${languages.length} langue(s) — la '
          'description et ${textChapters.length} chapitre(s) sont '
          'disponibles pour les étudiants.',
        ),
      ),
    );
  }

  /// Sélecteur des langues cibles (Anglais, Arabe, Espagnol).
  Future<List<CourseLanguage>> _pickTranslationLanguages() async {
    final selected = <CourseLanguage>{};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Traduire le cours',
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "L'IA traduit la description et les chapitres texte ; les "
                'traductions sont enregistrées et lisibles par tous les '
                'étudiants (sans coût supplémentaire).',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 8),
              for (final language in CourseLanguage.available)
                CheckboxListTile(
                  value: selected.contains(language),
                  onChanged: (checked) => setDialogState(
                    () => checked == true
                        ? selected.add(language)
                        : selected.remove(language),
                  ),
                  title: Text(
                    language.label,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: CourseColors.primary,
              ),
              child: const Text('Traduire'),
            ),
          ],
        ),
      ),
    );
    return confirmed == true ? selected.toList() : [];
  }

  /// Ouvre une `ModalBottomSheet` contextuelle permettant d'éditer le chapitre
  /// via `ChapterEditSheet.open` ou de le retirer via `CoursesController.deleteChapter`.
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
                  // Confirmation préalable : suppression d'un contenu
                  // destructrice pour la progression des étudiants.
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text(
                          'Supprimer ce chapitre ?',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        content: Text(
                          '« ${chapter.title} » sera définitivement retiré '
                          'du cours et la progression des étudiants sera '
                          'ajustée.',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Annuler'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: CourseColors.danger,
                            ),
                            child: const Text('Supprimer'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !mounted) return;
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

  /// Affiche une `ModalBottomSheet` détaillant l'avancement d'un étudiant inscrit :
  /// anneau `ProgressRing`, date du dernier accès et liste des chapitres validés en lecture seule.
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

  // Fonctions utilitaires de formatage pour l'affichage.

  /// Formate un `DateTime` sous la forme `JJ/MM/AAAA` (ex. `24/10/2026`).
  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  /// Extrait une ou deux initiales en majuscules à partir du nom complet pour le `CircleAvatar`.
  String _initials(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  // Construction réactive de l'arbre de widgets.

  @override
  Widget build(BuildContext context) {
    // Écoute `CoursesController` afin de refléter instantanément l'ajout, la suppression,
    // le réordonnancement de chapitres et le changement de statut de publication.
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
                tooltip: 'Traduire le cours (IA)',
                onPressed: () => _translateCourse(course),
                icon: const Icon(
                  Icons.translate_rounded,
                  color: Color(0xFF7C3AED),
                ),
              ),
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

  /// Aligne trois cartes `StatCard` de largeur égale (`Expanded`) pour les métriques du cours.
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

  /// Construit la section de gestion des chapitres : bouton d'ajout vers `ChapterEditSheet`
  /// et liste réordonnable (`ReorderableListView.builder`) déléguant la nouvelle position
  /// à `CoursesController.reorderChapters`.
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
          // Liste réordonnable sans poignées implicites : seule la poignée dédiée
          // `ReorderableDragStartListener` déclenche le déplacement de la tuile identifiée par `ValueKey`.
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

  /// Liste les étudiants inscrits au cours avec leur barre `ProgressBar` et ouvre
  /// la feuille de suivi détaillé au clic (`InkWell`) sur une ligne.
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
