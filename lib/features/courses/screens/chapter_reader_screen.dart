import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/courses_mock_data.dart';
import '../models/courses_models.dart';
import '../widgets/chapter_tile.dart';
import '../widgets/courses_ui.dart';

// ============================================================================
// LECTEUR DE CHAPITRES (ChapterReaderScreen) — ROUTE POUSSÉE, plein écran
// Métier 2 : lecture des chapitres selon leur type (texte, PDF, vidéo, lien)
// et « reprise là où l'on s'est arrêté ».
// Signature du module : la barre coulissante (DraggableScrollableSheet) —
// un coup d'œil montre la progression, un glissement vers le haut révèle
// la liste complète des chapitres avec leur état de complétion.
// ============================================================================

class ChapterReaderScreen extends StatefulWidget {
  final String courseId;
  final String chapterId;

  const ChapterReaderScreen({
    super.key,
    required this.courseId,
    required this.chapterId,
  });

  @override
  State<ChapterReaderScreen> createState() => _ChapterReaderScreenState();
}

class _ChapterReaderScreenState extends State<ChapterReaderScreen> {
  final CoursesController _controller = CoursesController.instance;

  /// Hauteur d'accueil de la barre coulissante (fraction de l'écran)
  static const double _peekSize = 0.22;

  late String _currentChapterId = widget.chapterId;

  void _selectChapter(String chapterId) {
    setState(() => _currentChapterId = chapterId);
  }

  void _goToRelativeChapter(List<Chapter> chapters, int offset) {
    final index = chapters.indexWhere((c) => c.id == _currentChapterId);
    final target = index + offset;
    if (target >= 0 && target < chapters.length) {
      _selectChapter(chapters[target].id);
    }
  }

  /// Marque le chapitre comme terminé / non terminé et célèbre la fin du cours
  /// (l'attribution du badge « Premier pas » se fera via la liaison L2).
  void _toggleCompleted(Chapter chapter, bool currentlyCompleted) {
    final enrollment = _controller.enrollmentFor(widget.courseId);
    final before = enrollment?.completedChapterIds.length ?? 0;
    _controller.setChapterCompleted(
      widget.courseId,
      chapter.id,
      !currentlyCompleted,
    );
    final after = _controller.enrollmentFor(widget.courseId)
        ?.completedChapterIds
        .length;

    final total = _controller.chaptersOf(widget.courseId).length;
    if (!currentlyCompleted && after == total && before < total && total > 0) {
      _showCourseCompletedDialog();
    }
  }

  void _showCourseCompletedDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: CourseColors.successBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: CourseColors.success,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Cours terminé !',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: const Text(
          'Tous les chapitres sont terminés, progression 100 %. Un badge '
          '« Premier pas » sera attribué selon la liaison L2 '
          '(BadgesService — module M1).',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: FilledButton.styleFrom(
              backgroundColor: CourseColors.success,
            ),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final course = _controller.courseById(widget.courseId);
        final chapters = _controller.chaptersOf(widget.courseId);

        if (course == null || chapters.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
            ),
            body: EmptyState(
              icon: Icons.auto_stories_outlined,
              title: 'Aucun chapitre à lire',
              message:
                  "Ce cours ne contient pas encore de chapitres publiés par "
                  "l'enseignant.",
            ),
          );
        }

        final index =
            chapters.indexWhere((c) => c.id == _currentChapterId);
        Chapter chapter;
        if (index >= 0) {
          chapter = chapters[index];
        } else {
          _currentChapterId = chapters.first.id;
          chapter = chapters.first;
        }
        final safeIndex = chapters.indexOf(chapter);

        final enrollment = _controller.enrollmentFor(widget.courseId);
        final completedCount = enrollment?.completedChapterIds.length ?? 0;
        final isCompleted =
            enrollment?.completedChapterIds.contains(chapter.id) ?? false;

        return Scaffold(
          backgroundColor: CourseColors.scaffold,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chapitre ${safeIndex + 1} / ${chapters.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: CourseColors.text,
                  ),
                ),
                Text(
                  course.title,
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
          body: Stack(
            fit: StackFit.expand,
            children: [
              // --- Contenu du chapitre (sous la feuille coulissante) ---
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).size.height * _peekSize,
                  ),
                  child: _chapterContent(chapter, safeIndex),
                ),
              ),
              // --- Barre coulissante des chapitres (slide-up bar) ---
              DraggableScrollableSheet(
                initialChildSize: _peekSize,
                minChildSize: _peekSize,
                maxChildSize: 0.92,
                snap: true,
                snapSizes: const [_peekSize, 0.55],
                builder: (context, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      border: Border.fromBorderSide(
                        BorderSide(color: CourseColors.border),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Poignée de glissement
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: CourseColors.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        // Aperçu fixe : progression + navigation
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
                          child: Row(
                            children: [
                              ProgressRing(
                                value: chapters.isEmpty
                                    ? 0
                                    : completedCount / chapters.length,
                                size: 38,
                                strokeWidth: 4,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Chapitre ${safeIndex + 1} · ${chapter.type.label}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: CourseColors.muted,
                                      ),
                                    ),
                                    Text(
                                      chapter.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: CourseColors.text,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Chapitre précédent',
                                onPressed: safeIndex == 0
                                    ? null
                                    : () => _goToRelativeChapter(
                                          chapters,
                                          -1,
                                        ),
                                icon: const Icon(
                                  Icons.chevron_left_rounded,
                                  color: CourseColors.textSecondary,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Chapitre suivant',
                                onPressed: safeIndex == chapters.length - 1
                                    ? null
                                    : () => _goToRelativeChapter(
                                          chapters,
                                          1,
                                        ),
                                icon: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: CourseColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Action principale : marquer comme terminé
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                          child: SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: isCompleted
                                ? OutlinedButton.icon(
                                    onPressed: () =>
                                        _toggleCompleted(chapter, true),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: CourseColors.success,
                                      side: const BorderSide(
                                        color: CourseColors.success,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.check_circle_rounded,
                                      size: 17,
                                    ),
                                    label: const Text(
                                      'Chapitre terminé — annuler',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  )
                                : FilledButton.icon(
                                    onPressed: () =>
                                        _toggleCompleted(chapter, false),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: CourseColors.success,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.done_all_rounded,
                                      size: 17,
                                    ),
                                    label: const Text(
                                      'Marquer comme terminé',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const Divider(height: 1),
                        // Liste complète des chapitres (zone déplaçable)
                        Expanded(
                          child: ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            children: [
                              const Text(
                                'Chapitres du cours — glissez vers le haut',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: CourseColors.muted,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...chapters.map(
                                (c) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: ChapterTile(
                                    chapter: c,
                                    number: chapters.indexOf(c) + 1,
                                    completed: enrollment?.completedChapterIds
                                            .contains(c.id) ??
                                        false,
                                    highlighted: c.id == chapter.id,
                                    onTap: () => _selectChapter(c.id),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Rendu du contenu selon le type du chapitre
  // ===========================================================================

  Widget _chapterContent(Chapter chapter, int index) {
    switch (chapter.type) {
      case ChapterType.text:
        return _textContent(chapter, index);
      case ChapterType.pdf:
        return _pdfContent(chapter);
      case ChapterType.video:
        return _videoContent(chapter);
      case ChapterType.link:
        return _linkContent(chapter);
    }
  }

  Widget _textContent(Chapter chapter, int index) {
    final paragraphs =
        (chapter.content ?? '').split('\n\n').where((p) => p.isNotEmpty);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChapterTypeBadge(type: chapter.type),
              const SizedBox(width: 8),
              Text(
                'Chapitre ${index + 1} · ${chapter.durationMin} min',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: CourseColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            chapter.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.25,
              color: CourseColors.text,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: CourseColors.border),
          const SizedBox(height: 8),
          ...paragraphs.map(
            (paragraph) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                paragraph,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.7,
                  color: CourseColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// PDF : visionneuse simplifiée — le fichier est stocké en privé sur
  /// Cloudinary (liaison L10, MediaService exposé par M2).
  Widget _pdfContent(Chapter chapter) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: CourseColors.infoBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                size: 36,
                color: CourseColors.danger,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Support PDF',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: CourseColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              chapter.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: CourseColors.muted,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: CourseColors.neutralBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                chapter.content ?? 'fichier privé',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  color: CourseColors.muted,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 280,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      duration: Duration(seconds: 2),
                      content: Text(
                        'Liaison L10 — téléchargement via MediaService '
                        '(Cloudinary) : branchement semaine 2.',
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: CourseColors.primary,
                  side: const BorderSide(color: CourseColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text(
                  'Télécharger le support',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fichier privé — accessible aux étudiants inscrits.',
              style: TextStyle(
                fontSize: 10.5,
                color: CourseColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Vidéo : lecteur intégré simulé — le titre et la miniature sont
  /// récupérés via YouTube oEmbed (API externe n°2 de M2, sans clé).
  Widget _videoContent(Chapter chapter) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_circle_rounded,
                      size: 46,
                      color: Colors.white,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Lecture vidéo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: courseCardDecoration(),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.smart_display_rounded,
                    color: Color(0xFF7C3AED),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vidéo YouTube',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: CourseColors.text,
                        ),
                      ),
                      Text(
                        chapter.content ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: CourseColors.muted,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Copier le lien',
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: chapter.content ?? ''),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        duration: Duration(seconds: 2),
                        content: Text('Lien de la vidéo copié.'),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.copy_rounded,
                    color: CourseColors.primary,
                    size: 19,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Titre et miniature récupérés via YouTube oEmbed '
              '(API externe gratuite, sans clé).',
              style: TextStyle(
                fontSize: 10.5,
                color: CourseColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Lien externe : ressource hébergée hors application
  Widget _linkContent(Chapter chapter) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: CourseColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.link_rounded,
                size: 36,
                color: CourseColors.success,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Ressource externe',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: CourseColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              chapter.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: CourseColors.muted,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(
                color: CourseColors.neutralBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                chapter.content ?? '',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: CourseColors.muted,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: chapter.content ?? ''),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        duration: Duration(seconds: 2),
                        content: Text('Lien copié.'),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CourseColors.textSecondary,
                    side: const BorderSide(color: CourseColors.border),
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 17),
                  label: const Text(
                    'Copier',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          duration: Duration(seconds: 2),
                          content: Text(
                            'Ouverture externe — url_launcher à brancher '
                            '(semaine 2).',
                          ),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: CourseColors.success,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    label: const Text(
                      'Ouvrir',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
