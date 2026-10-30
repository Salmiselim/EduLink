import 'package:flutter/material.dart';

/// Palette de couleurs partagée par l'ensemble des écrans et widgets du Forum,
/// cohérente avec la charte graphique globale d'EduLink.
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

/// Construit une `InputDecoration` standardisée (coins arrondis de rayon 14 et
/// bordure `ForumColors.border`) pour les champs de formulaire du Forum.
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

/// Décoration commune des conteneurs de cartes (`PostCard`, `AnswerCard`, énoncé détaillé).
BoxDecoration forumCardDecoration({Color borderColor = ForumColors.border}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: borderColor),
  );
}

/// Puce compacte réutilisée pour afficher le cours associé, le rôle d'un auteur
/// (`RoleBadge`) ou la mention « Réponse vérifiée ».
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
          // `Flexible` évite tout dépassement horizontal si l'intitulé du cours est long.
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

/// Avatar circulaire générant l'initiale de l'utilisateur avec une teinte bleue
/// pour les enseignants et grise neutre pour les étudiants.
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

/// En-tête d'`AppBar` principal combinant un pictogramme encadré, un titre et un sous-titre.
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

/// Titre typographique standard utilisé dans l'`AppBar` des écrans secondaires du Forum.
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

/// Composant d'état vide générique affichant une icône, un titre, un message explicatif
/// et un widget d'action optionnel (réinitialisation de filtres ou retour arrière).
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

/// Bouton d'action principal pleine largeur (`FilledButton.icon`) utilisé pour la validation.
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
