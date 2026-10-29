import 'package:flutter/material.dart';
import '../models/courses_models.dart';

// ============================================================================
// KIT UI PARTAGÉ — MODULE M2 : COURS
// Palette et primitives conformes à la charte graphique EduLink
// (MARKETPLACE_GUIDE.md — mêmes valeurs que `EduColors` du module M4).
// ============================================================================

/// Palette de la charte graphique EduLink
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

/// Décoration standard des champs de saisie (Formulaires — critère 4)
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

/// Décoration standard des cartes : fond blanc, radius 16, bordure 1px
BoxDecoration courseCardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: CourseColors.border),
  );
}

/// Badge matière (bleu — 10 % d'opacité, police 11/w700)
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

/// Badge niveau académique (L1 à M2 — neutre ardoise)
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

/// Badge de statut de publication (« Publié » vert / « Brouillon » ambre)
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

/// Badge du type de chapitre (Texte / PDF / Vidéo / Lien)
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

/// Pastille réutilisable (badge 11/w700, radius 8, fond 10 % d'opacité)
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

/// Titre de section (15.5 / w800 — échelle typographique de la charte)
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

/// État vide conçu (icône, titre, message et action facultative) — chaque vue
/// du module doit fournir un état vide, jamais un écran blanc.
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

/// Carte de statistique du tableau de bord (valeur + libellé + icône)
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

/// Barre de progression linéaire (hauteur 6, radius plein)
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

/// Anneau de progression avec pourcentage centré
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

/// Ligne « icône + libellé + valeur » des récapitulatifs (wizard, feuilles)
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
