import 'package:flutter/material.dart';
import '../models/courses_models.dart';

// Composants visuels atomiques et constantes de thème partagés par tous les écrans
// et feuilles modales du module Cours.

/// Palette de couleurs centralisée assurant l'homogénéité visuelle des écrans du module.
class CourseColors {
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1E3A8A);
  static const Color scaffold = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color text = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF334155);
  static const Color muted = Color(0xFF64748B);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color infoBg = Color(0xFFDBEAFE);
  static const Color neutralBg = Color(0xFFF1F5F9);
}

/// Génère un `InputDecoration` uniforme pour tous les `TextField`, `TextFormField`
/// et `DropdownButtonFormField` du module Cours.
InputDecoration courseInputDecoration({
  required String label,
  String? hint,
  IconData? icon,
  String? counterText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    counterText: counterText,
    prefixIcon: icon == null ? null : Icon(icon, color: CourseColors.muted),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: CourseColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: CourseColors.primary, width: 1.6),
    ),
  );
}

/// Retourne la décoration standard des conteneurs de carte (fond blanc, coins arrondis 16 px et bordure fine).
BoxDecoration courseCardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: CourseColors.border),
  );
}

/// Pastille bleue identifiant la matière académique d'un cours.
class SubjectBadge extends StatelessWidget {
  final String subject;

  const SubjectBadge({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    return _pill(
      subject,
      color: CourseColors.primary,
      background: CourseColors.infoBg,
      icon: Icons.sell_outlined,
    );
  }
}

/// Pastille neutre affichant le niveau universitaire ciblé (de la Licence 1 au Master 2).
class LevelBadge extends StatelessWidget {
  final String level;

  const LevelBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return _pill(
      level,
      color: CourseColors.muted,
      background: CourseColors.neutralBg,
      icon: Icons.school_outlined,
    );
  }
}

/// Pastille d'état indiquant si un cours enseignant est « Publié » ou en « Brouillon ».
class CourseStatusBadge extends StatelessWidget {
  final bool isPublished;

  const CourseStatusBadge({super.key, required this.isPublished});

  @override
  Widget build(BuildContext context) {
    return isPublished
        ? _pill(
            'Publié',
            color: CourseColors.success,
            background: CourseColors.successBg,
            icon: Icons.check_circle_rounded,
          )
        : _pill(
            'Brouillon',
            color: CourseColors.warning,
            background: CourseColors.warningBg,
            icon: Icons.edit_note_rounded,
          );
  }
}

/// Pastille colorée selon `ChapterTypeX` identifiant le format d'un chapitre (Texte, PDF, Vidéo, Lien).
class ChapterTypeBadge extends StatelessWidget {
  final ChapterType type;

  const ChapterTypeBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return _pill(
      type.label,
      color: type.color,
      background: type.background,
      icon: type.icon,
    );
  }
}

/// Fonction interne construisant la structure commune aux différents badges du module.
Widget _pill(
  String label, {
  required Color color,
  required Color background,
  IconData? icon,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

/// En-tête de section affichant un titre, un compteur facultatif entre parenthèses et un widget d'action à droite.
class SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.count, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            count == null ? title : '$title ($count)',
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: CourseColors.text,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// Vue générique d'état vide affichant une icône illustrée, un message explicatif
/// et un bouton d'action facultatif lorsqu'une liste ou une recherche ne renvoie aucun élément.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: CourseColors.infoBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: CourseColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: CourseColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: CourseColors.muted,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: CourseColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tuile synthétique affichant un indicateur chiffré avec son icône dans les vues enseignant.
class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color = CourseColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: courseCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: CourseColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: CourseColors.muted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Barre d'avancement linéaire arrondie encapsulant un `LinearProgressIndicator` borné entre `0.0` et `1.0`.
class ProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;

  const ProgressBar({
    super.key,
    required this.value,
    this.color = CourseColors.primary,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: CourseColors.neutralBg,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

/// Indicateur circulaire d'avancement (`CircularProgressIndicator`) superposant le pourcentage entier au centre.
class ProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final double strokeWidth;
  final Color color;

  const ProgressRing({
    super.key,
    required this.value,
    this.size = 44,
    this.strokeWidth = 5,
    this.color = CourseColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (value.clamp(0.0, 1.0) * 100).round();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: value.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              backgroundColor: CourseColors.neutralBg,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Text(
            '$percent%',
            style: TextStyle(
              fontSize: size >= 44 ? 11 : 9.5,
              fontWeight: FontWeight.w800,
              color: CourseColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne clé-valeur avec icône utilisée dans les encarts récapitulatifs d'inscription et de publication.
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: CourseColors.muted),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: CourseColors.muted,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: CourseColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
