import 'package:flutter/material.dart';
import '../models/courses_models.dart';
import 'courses_ui.dart';

// ============================================================================
// LIGNE DE CHAPITRE RÉUTILISABLE — MODULE M2 : COURS
// Utilisée dans : la page du cours, le lecteur (feuille coulissante),
// l'assistant de création (réordonnancement) et le tableau de bord enseignant.
// ============================================================================

class ChapterTile extends StatelessWidget {
  final Chapter chapter;

  /// Numéro affiché (1-based)
  final int number;

  /// Chapitre terminé par l'étudiant (coche verte)
  final bool completed;

  /// Chapitre en cours de lecture (surbrillance bleue)
  final bool highlighted;

  final VoidCallback? onTap;

  /// Poignée de réordonnancement (assistant & gestion enseignant)
  final bool showDragHandle;

  /// Widget replacement pour la zone de droite (menu ⋮ enseignant, etc.)
  final Widget? trailingOverride;

  const ChapterTile({
    super.key,
    required this.chapter,
    required this.number,
    this.completed = false,
    this.highlighted = false,
    this.onTap,
    this.showDragHandle = false,
    this.trailingOverride,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        highlighted ? CourseColors.primary : CourseColors.border;

    return Material(
      color: highlighted ? CourseColors.infoBg : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              _leading(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: CourseColors.text,
                        decoration:
                            completed ? TextDecoration.lineThrough : null,
                        decorationColor: CourseColors.muted,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        ChapterTypeBadge(type: chapter.type),
                        const SizedBox(width: 8),
                        Icon(Icons.schedule_rounded,
                            size: 12, color: CourseColors.muted),
                        const SizedBox(width: 3),
                        Text(
                          '${chapter.durationMin} min',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: CourseColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (trailingOverride != null)
                trailingOverride!
              else if (showDragHandle)
                const Icon(
                  Icons.drag_indicator_rounded,
                  color: CourseColors.muted,
                  size: 20,
                )
              else if (completed)
                const Icon(
                  Icons.check_circle_rounded,
                  color: CourseColors.success,
                  size: 20,
                )
              else if (highlighted)
                const Icon(
                  Icons.play_circle_rounded,
                  color: CourseColors.primary,
                  size: 20,
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: CourseColors.muted,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pastille du numéro de chapitre (coche verte si terminé)
  Widget _leading() {
    if (completed) {
      return Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          color: CourseColors.successBg,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 16,
          color: CourseColors.success,
        ),
      );
    }
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: CourseColors.neutralBg,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: CourseColors.muted,
        ),
      ),
    );
  }
}
