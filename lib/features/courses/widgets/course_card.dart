import 'dart:io';

import 'package:flutter/material.dart';
import '../models/courses_models.dart';
import '../services/courses_document_service.dart';
import 'courses_ui.dart';

// Carte polymorphe représentant un `Course` dans les listes de `CoursesScreen`.
// Décline trois configurations visuelles à partir d'un seul composant :
// - catalogue étudiant   : bouton d'inscription rapide ou anneau si déjà inscrit ;
// - cours suivis étudiant : barre `ProgressBar` et indication du prochain chapitre ;
// - gestion enseignant   : badge de publication (`CourseStatusBadge`) et menu d'options.

/// Carte interactive (`InkWell`) présentant un cours avec vignette, badges (`Wrap`) et action contextuelle.
class CourseCard extends StatelessWidget {
  final Course course;
  final bool isTeacherVariant;
  final double? progress;
  final bool enrolled;
  final String? continueLabel;
  final VoidCallback? onTap;
  final VoidCallback? onEnroll;
  final VoidCallback? onMore;

  const CourseCard({
    super.key,
    required this.course,
    this.isTeacherVariant = false,
    this.progress,
    this.enrolled = false,
    this.continueLabel,
    this.onTap,
    this.onEnroll,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: courseCardDecoration(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _cover(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        color: CourseColors.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Badges matière et niveau (passent à la ligne si besoin).
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        SubjectBadge(subject: course.subject),
                        LevelBadge(level: course.level),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Wrap et non Row : avec un grand nombre d'inscrits ou le
                    // badge de statut (variante enseignant), les éléments
                    // passent à la ligne au lieu de déborder de la carte —
                    // c'était le cas dans le carrousel « Recommandés » (300 px)
                    // et sur les listes enseignant.
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Icon(
                          Icons.menu_book_outlined,
                          size: 12,
                          color: CourseColors.muted,
                        ),
                        Text(
                          '${course.chaptersCount} chap.',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: CourseColors.muted,
                          ),
                        ),
                        const Icon(
                          Icons.group_outlined,
                          size: 12,
                          color: CourseColors.muted,
                        ),
                        Text(
                          '${course.enrollmentsCount} inscrits',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: CourseColors.muted,
                          ),
                        ),
                        if (isTeacherVariant)
                          CourseStatusBadge(isPublished: course.isPublished),
                      ],
                    ),
                    if (!isTeacherVariant && progress != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ProgressBar(value: progress!),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(progress!.clamp(0.0, 1.0) * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: CourseColors.text,
                            ),
                          ),
                        ],
                      ),
                      if (continueLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          continueLabel!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: CourseColors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _trailing(),
            ],
          ),
        ),
      ),
    );
  }

  /// Affiche la miniature du cours : image locale importée par l'enseignant
  /// (référence `edulink_files/...` résolue sur l'appareil), URL réseau le
  /// cas échéant, avec repli automatique sur `_gradientFallback` sinon.
  Widget _cover() {
    Widget child;
    final cover = course.coverImageUrl;
    if (CoursesDocumentService.isLocalReference(cover)) {
      child = FutureBuilder<File?>(
        future: CoursesDocumentService.instance.resolveLocalFile(cover),
        builder: (context, snapshot) {
          final file = snapshot.data;
          if (file == null) return _gradientFallback();
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              file,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _gradientFallback(),
            ),
          );
        },
      );
    } else if (cover != null && cover.isNotEmpty) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          cover,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _gradientFallback(),
        ),
      );
    } else {
      child = _gradientFallback();
    }
    return SizedBox(width: 64, height: 64, child: child);
  }

  /// Vignette par défaut à dégradé bleu affichée lorsqu'aucune image de couverture n'est disponible.
  Widget _gradientFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CourseColors.primary, CourseColors.primaryDark],
        ),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: const Icon(
        Icons.menu_book_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }

  /// Sélectionne le widget de fin de ligne selon le contexte : menu d'options enseignant,
  /// anneau `ProgressRing` pour un inscrit, bouton `OutlinedButton` d'inscription ou chevron.
  Widget _trailing() {
    if (isTeacherVariant) {
      return IconButton(
        tooltip: 'Actions du cours',
        onPressed: onMore,
        icon: const Icon(
          Icons.more_vert_rounded,
          color: CourseColors.muted,
          size: 20,
        ),
      );
    }
    if (enrolled) {
      return ProgressRing(value: progress ?? 0, size: 40, strokeWidth: 4);
    }
    if (onEnroll != null) {
      return OutlinedButton(
        onPressed: onEnroll,
        style: OutlinedButton.styleFrom(
          foregroundColor: CourseColors.primary,
          side: const BorderSide(color: CourseColors.primary, width: 1.4),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        child: const Text(
          "S'inscrire",
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
        ),
      );
    }
    return const Icon(
      Icons.chevron_right_rounded,
      color: CourseColors.muted,
      size: 22,
    );
  }
}
