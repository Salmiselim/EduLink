import 'package:flutter/material.dart';

// ============================================================================
// KIT UI PARTAGÉ — MODULE M3 : FORUM (Q&A)
// Palette et primitives conformes à la charte graphique EduLink
// (MARKETPLACE_GUIDE.md) : mêmes valeurs que `CourseColors` (M2) et
// `EduColors` (M4).
// ============================================================================

/// Palette de la charte graphique EduLink
class ForumColors {
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

/// Décoration standard des champs de saisie (rayon 14, bordure E2E8F0)
InputDecoration forumInputDecoration({
  required String label,
  String? hint,
  IconData? icon,
  String? counterText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    counterText: counterText,
    prefixIcon: icon == null ? null : Icon(icon, color: ForumColors.muted),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: ForumColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: ForumColors.primary, width: 1.6),
    ),
  );
}

/// Décoration standard des cartes : fond blanc, rayon 16, bordure 1px
BoxDecoration forumCardDecoration({Color borderColor = ForumColors.border}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: borderColor),
  );
}

/// Badge / puce (11 / w700, rayon 8, fond 10 % d'opacité par défaut)
class ForumPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color? background;
  final IconData? icon;

  const ForumPill({
    super.key,
    required this.label,
    required this.color,
    this.background,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar à initiale : bleu pour un enseignant, neutre pour un étudiant
class ForumAvatar extends StatelessWidget {
  final String name;
  final bool isTeacher;
  final double radius;

  const ForumAvatar({
    super.key,
    required this.name,
    this.isTeacher = false,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          isTeacher ? ForumColors.infoBg : ForumColors.neutralBg,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.85,
          color: isTeacher ? ForumColors.primary : ForumColors.textSecondary,
        ),
      ),
    );
  }
}

/// Logo + titre de l'AppBar d'un module (« EduLink · Forum »)
class ForumModuleTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const ForumModuleTitle({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ForumColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: ForumColors.text,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: ForumColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Titre d'AppBar d'un écran poussé (17 / w800)
class ForumPageTitle extends StatelessWidget {
  final String text;

  const ForumPageTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: ForumColors.text,
      ),
    );
  }
}

/// État vide : icône 42, titre 16 / w800, sous-titre 13.5
class ForumEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const ForumEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: ForumColors.muted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: ForumColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: ForumColors.muted),
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            action!,
          ],
        ],
      ),
    );
  }
}

/// CTA principal : hauteur 50, rayon 14, texte w800
class ForumPrimaryCta extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const ForumPrimaryCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.arrow_forward_rounded),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: ForumColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
