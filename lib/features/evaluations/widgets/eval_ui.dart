import 'package:flutter/material.dart';

/// Palette et helpers UI — Charte graphique EduLink (Design System d'équipe M1-M5)
class EduColors {
  // Couleurs de base EduLink
  static const Color primary = Color(0xFF2563EB); // Bleu EduLink
  static const Color primaryDark = Color(0xFF1E3A8A);
  static const Color scaffold = Color(0xFFF8FAFC); // Fond gris-bleuté très clair
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E8F0); // Bordure subtile 1px
  static const Color text = Color(0xFF0F172A); // Slate 900 (Titres)
  static const Color textSecondary = Color(0xFF334155); // Slate 700 (Corps)
  static const Color muted = Color(0xFF64748B); // Slate 500/600 (Sous-titres)

  // Couleurs sémantiques de statuts
  static const Color success = Color(0xFF16A34A); // Vert émeraude
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFD97706); // Ambre
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFDC2626); // Rouge
  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color infoBg = Color(0xFFDBEAFE); // Bleu 10%
  static const Color neutralBg = Color(0xFFF1F5F9); // Gris ardoise 10%

  // Couleurs des dossiers Blackboard
  static const Color folderPolycopies = Color(0xFF2563EB); // Bleu
  static const Color folderCorriges = Color(0xFF16A34A); // Vert
  static const Color folderAnnales = Color(0xFF7C3AED); // Violet
}

/// Décoration d'input Material 3 standardisée EduLink (rayon 14px)
InputDecoration evalInputDecoration({
  required String label,
  String? hint,
  IconData? icon,
  Widget? suffixIcon,
  String? counterText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    counterText: counterText,
    prefixIcon: icon == null
        ? null
        : Icon(icon, color: EduColors.muted, size: 20),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    labelStyle: const TextStyle(
      fontSize: 13.5,
      color: EduColors.muted,
      fontWeight: FontWeight.w500,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: EduColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: EduColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: EduColors.primary, width: 1.8),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: EduColors.danger, width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: EduColors.danger, width: 1.8),
    ),
  );
}

/// Décoration de carte EduLink (fond blanc, bordure 1px, rayon 16px, élévation 0)
BoxDecoration evalCardDecoration({
  Color? color,
  Color? borderColor,
  double radius = 16,
}) {
  return BoxDecoration(
    color: color ?? Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor ?? EduColors.border, width: 1),
  );
}

/// Badge sémantique avec texte 11.5pt gras et fond avec opacité adaptée
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color? background;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.background,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12.5, color: color),
            const SizedBox(width: 4.5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte indicateur KPI pour les en-têtes statistiques (Moyenne, Activité, etc.)
class KpiStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const KpiStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: evalCardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: EduColors.muted,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: EduColors.text,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// État vide standardisé avec icône, titre et sous-titre
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: EduColors.neutralBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 38, color: EduColors.muted),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: EduColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: EduColors.muted,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

/// En-tête de section standardisé
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: EduColors.text,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: EduColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Bouton CTA principal EduLink (hauteur 50px, rayon 14px)
class PrimaryCta extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? backgroundColor;

  const PrimaryCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.arrow_forward_rounded, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor ?? EduColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

/// Formate une date en chaîne claire en français
String formatDate(DateTime d) {
  const months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${months[d.month - 1]} ${d.year} · $hh:$mm';
}

/// Formate une note sur une note maximale
String formatGrade(double? grade, double max) {
  if (grade == null) return '— / ${max.toStringAsFixed(0)}';
  final g = grade == grade.roundToDouble()
      ? grade.toInt().toString()
      : grade.toStringAsFixed(1);
  return '$g / ${max.toStringAsFixed(0)}';
}
