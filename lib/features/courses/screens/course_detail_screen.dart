import 'package:flutter/material.dart';
import '../../marketplace/data/marketplace_mock_data.dart';
import '../../marketplace/models/marketplace_models.dart';
import '../../marketplace/routes/marketplace_routes.dart';
import '../data/courses_mock_data.dart';
import '../models/courses_models.dart';
import '../routes/courses_routes.dart';
import '../widgets/chapter_tile.dart';
import '../widgets/courses_ui.dart';

// ============================================================================
// PAGE D'UN COURS (CourseDetailScreen) — ROUTE POUSSÉE
// Métier 2 : « recherche et filtres, inscription, lecture des chapitres,
// reprise là où l'on s'est arrêté ; boutons Poser une question (forum du
// cours, L3), Évaluations (L5) et Ressources liées (L6) ».
// ============================================================================

class CourseDetailScreen extends StatefulWidget {
  final String courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final CoursesController _controller = CoursesController.instance;
  final MarketplaceController _marketplace = MarketplaceController.instance;

  bool get _isOwner =>
      _controller.courseById(widget.courseId)?.teacherId ==
      _controller.currentUserId;

  /// Feuille coulissante « Ressources liées » : offres de la
  /// Marketplace rattachées à ce cours via `offers.courseId`. En attendant le
  /// backend NestJS, la lecture se fait directement sur le contrôleur Marketplace
  /// (équivalent de `OffersService.listByCourse(courseId)`).
  void _openLinkedResourcesSheet(Course course) {
    final offers = _marketplace.allOffers
        .where(
          (o) => o.courseId == course.id && o.status == OfferStatus.published,
        )
        .toList();

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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: CourseColors.infoBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: CourseColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Ressources liées au cours',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: CourseColors.text,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: CourseColors.neutralBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Marketplace',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: CourseColors.muted,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (offers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      "Aucune offre rattachée à ce cours pour le moment.\n"
                      'Les enseignants et étudiants peuvent publier des '
                      "ressources liées depuis la Marketplace (assistant M5, "
                      'étape 5).',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: CourseColors.muted,
                      ),
                    ),
                  )
                else
                  ...offers.map((offer) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: _offerColor(offer.type)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _offerIcon(offer.type),
                            color: _offerColor(offer.type),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          offer.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: CourseColors.text,
                          ),
                        ),
                        subtitle: Text(
                          '${offer.sellerName} · '
                          '${offer.price == 0 ? 'Gratuit' : '${offer.price.toStringAsFixed(0)} TND'}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: CourseColors.muted,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: CourseColors.muted,
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Navigator.pushNamed(
                            context,
                            MarketplaceRoutes.offerDetail,
                            arguments: OfferDetailArgs(offerId: offer.id),
                          );
                        },
                      )),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Couleurs des types d'offre — palette de la charte M5
  Color _offerColor(OfferType type) {
    switch (type) {
      case OfferType.resourceDigital:
        return const Color(0xFF2563EB);
      case OfferType.resourcePhysical:
        return const Color(0xFFD97706);
      case OfferType.privateLesson:
        return const Color(0xFF7C3AED);
    }
  }

  IconData _offerIcon(OfferType type) {
    switch (type) {
      case OfferType.resourceDigital:
        return Icons.picture_as_pdf_rounded;
      case OfferType.resourcePhysical:
        return Icons.menu_book_rounded;
      case OfferType.privateLesson:
        return Icons.co_present_rounded;
    }
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

  void _openReader(Course course, String chapterId) {
    Navigator.pushNamed(
      context,
      CoursesRoutes.chapterReader,
      arguments: ChapterReaderArgs(courseId: course.id, chapterId: chapterId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_controller, _marketplace]),
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

        final chapters = _controller.chaptersOf(course.id);
        final enrollment = _controller.enrollmentFor(course.id);
        final isEnrolled = enrollment != null;

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
              if (_isOwner)
                IconButton(
                  tooltip: 'Gérer le cours',
                  onPressed: () => Navigator.pushNamed(
                    context,
                    CoursesRoutes.courseManage,
                    arguments: CourseManageArgs(courseId: course.id),
                  ),
                  icon: const Icon(
                    Icons.tune_rounded,
                    color: CourseColors.primary,
                  ),
                ),
              const SizedBox(width: 4),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- Bannière de couverture (dégradé EduLink) ---
              _heroBanner(course),
              const SizedBox(height: 16),
              Text(
                course.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                  color: CourseColors.text,
                ),
              ),
              const SizedBox(height: 10),
              // Enseignant (profil public)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      duration: Duration(seconds: 2),
                      content: Text(
                        'Profil public de l\'enseignant — '
                        'intégration à venir.',
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: CourseColors.infoBg,
                        child: Text(
                          course.teacherName
                              .split(' ')
                              .map((part) => part.isEmpty ? '' : part[0])
                              .take(2)
                              .join(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: CourseColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        course.teacherName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: CourseColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: course.teacherVerified
                              ? CourseColors.infoBg
                              : CourseColors.neutralBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              course.teacherVerified
                                  ? Icons.verified_rounded
                                  : Icons.person_outline_rounded,
                              size: 12,
                              color: course.teacherVerified
                                  ? const Color(0xFF1D4ED8)
                                  : CourseColors.muted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              course.teacherVerified
                                  ? 'Enseignant vérifié'
                                  : 'Enseignant',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: course.teacherVerified
                                    ? const Color(0xFF1D4ED8)
                                    : CourseColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  SubjectBadge(subject: course.subject),
                  LevelBadge(level: course.level),
                  _metaPill(
                    Icons.format_list_numbered_rounded,
                    '${course.chaptersCount} chapitres',
                  ),
                  _metaPill(
                    Icons.schedule_rounded,
                    '${_controller.totalDurationMin(course.id)} min',
                  ),
                  _metaPill(
                    Icons.group_outlined,
                    '${course.enrollmentsCount} inscrits',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const SectionHeader(title: 'Description'),
              Text(
                course.description,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: CourseColors.textSecondary,
                ),
              ),
              // --- Carte de progression (étudiant inscrit) ---
              if (isEnrolled && !_isOwner) ...[
                const SizedBox(height: 18),
                _progressCard(course, enrollment),
              ],
              const SizedBox(height: 18),
              SectionHeader(title: 'Chapitres', count: chapters.length),
              if (chapters.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: courseCardDecoration(),
                  child: const Text(
                    "Le contenu de ce cours arrive bientôt — l'enseignant "
                    'n\'a pas encore ajouté de chapitres.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: CourseColors.muted,
                    ),
                  ),
                )
              else
                ...chapters.map(
                  (chapter) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ChapterTile(
                      chapter: chapter,
                      number: chapters.indexOf(chapter) + 1,
                      completed:
                          enrollment?.completedChapterIds.contains(chapter.id) ??
                              false,
                      onTap: () {
                        if (isEnrolled || _isOwner) {
                          _openReader(course, chapter.id);
                        } else {
                          _openEnrollSheet(course);
                        }
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              const SectionHeader(title: 'Aller plus loin'),
              _actionButton(
                icon: Icons.forum_outlined,
                label: 'Poser une question (forum du cours)',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      duration: Duration(seconds: 2),
                      content: Text(
                        'Forum du cours — '
                        'intégration à venir.',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              _actionButton(
                icon: Icons.quiz_outlined,
                label: 'Évaluations & notes du cours',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      duration: Duration(seconds: 2),
                      content: Text(
                        'Évaluations du cours — '
                        'intégration à venir.',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              _actionButton(
                icon: Icons.storefront_outlined,
                label: 'Ressources liées (Marketplace)',
                onPressed: () => _openLinkedResourcesSheet(course),
              ),
              const SizedBox(height: 24),
            ],
          ),
          // --- CTA principal collé en bas (zone du pouce) ---
          bottomNavigationBar: _bottomCta(
            course,
            chapters,
            isEnrolled,
          ),
        );
      },
    );
  }

  Widget? _bottomCta(Course course, List<Chapter> chapters, bool isEnrolled) {
    final bool isStudent = !_controller.isTeacher;

    String label;
    VoidCallback? onPressed;

    if (_isOwner) {
      label = 'Gérer le cours';
      onPressed = () => Navigator.pushNamed(
            context,
            CoursesRoutes.courseManage,
            arguments: CourseManageArgs(courseId: course.id),
          );
    } else if (isEnrolled) {
      label = 'Continuer le cours';
      onPressed = () {
        final next =
            _controller.nextChapterToRead(course.id) ??
                (chapters.isEmpty ? null : chapters.first);
        if (next != null) _openReader(course, next.id);
      };
    } else if (isStudent && course.isPublished) {
      label = "S'inscrire au cours — Gratuit";
      onPressed = () => _openEnrollSheet(course);
    } else {
      return null;
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: CourseColors.border)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: CourseColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroBanner(Course course) {
    return Container(
      height: 150,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CourseColors.primary, CourseColors.primaryDark],
        ),
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Stack(
        children: [
          const Center(
            child: Icon(
              Icons.menu_book_rounded,
              size: 52,
              color: Colors.white24,
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                course.level,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: CourseColors.primary,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.sell_rounded,
                    size: 12,
                    color: CourseColors.primaryDark,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    course.subject,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: CourseColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressCard(Course course, Enrollment enrollment) {
    final progress = _controller.progressOf(enrollment);
    final chapters = _controller.chaptersOf(course.id);
    final next = _controller.nextChapterToRead(course.id);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: courseCardDecoration(),
      child: Row(
        children: [
          ProgressRing(value: progress, size: 52, strokeWidth: 6),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ta progression',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: CourseColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                ProgressBar(value: progress),
                const SizedBox(height: 6),
                Text(
                  '${enrollment.completedChapterIds.length}/${chapters.length} chapitres terminés'
                  '${next == null ? '' : ' · à suivre : ${next.title}'}',
                  maxLines: 2,
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
        ],
      ),
    );
  }

  Widget _metaPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: CourseColors.neutralBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: CourseColors.muted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: CourseColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: CourseColors.textSecondary,
          side: const BorderSide(color: CourseColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerLeft,
        ),
        icon: Icon(icon, size: 18, color: CourseColors.primary),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
