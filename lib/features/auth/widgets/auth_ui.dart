import 'package:flutter/material.dart';

// ============================================================================
// KIT UI PARTAGÉ — AUTHENTIFICATION (connexion, inscription, mot de passe)
// Palette et primitives conformes à la charte graphique EduLink
// (MARKETPLACE_GUIDE.md). Interface de démonstration : toute saisie valide
// ouvre l'application ; la connexion réelle (Firebase Authentication) sera
// branchée par le module Comptes & Profils.
// ============================================================================

/// Palette de la charte graphique EduLink
class AuthColors {
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1E3A8A);
  static const Color scaffold = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color text = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF334155);
  static const Color muted = Color(0xFF64748B);
  static const Color success = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color infoBg = Color(0xFFDBEAFE);
  static const Color neutralBg = Color(0xFFF1F5F9);
}

/// Décoration standard des champs de saisie (cohérente avec les modules)
InputDecoration authInputDecoration({
  required String label,
  String? hint,
  IconData? icon,
  Widget? suffixIcon,
  String? helperText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helperText,
    prefixIcon: icon == null ? null : Icon(icon, color: AuthColors.muted),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AuthColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AuthColors.primary, width: 1.6),
    ),
  );
}

/// En-tête de marque : logo en dégradé EduLink + nom + slogan
class AuthHeader extends StatelessWidget {
  final String subtitle;

  const AuthHeader({super.key, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AuthColors.primary, AuthColors.primaryDark],
            ),
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          child: const Icon(
            Icons.school_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'EduLink',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AuthColors.text,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AuthColors.muted,
          ),
        ),
      ],
    );
  }
}

/// Bouton d'action principal (hauteur 50, radius 14 — charte)
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const AuthPrimaryButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AuthColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

/// Bouton social (Google / Apple) — fond blanc, bordure fine, logo de marque
class AuthSocialButton extends StatelessWidget {
  final Widget logo;
  final String label;
  final VoidCallback? onPressed;

  const AuthSocialButton({
    super.key,
    required this.logo,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AuthColors.text,
          backgroundColor: Colors.white,
          side: const BorderSide(color: AuthColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: logo,
        label: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Logo « G » de Google (lettre colorée sur pastille blanche)
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AuthColors.border),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }
}

/// Logo Apple (glyphe blanc sur pastille noire)
class AppleLogo extends StatelessWidget {
  const AppleLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      child: const Icon(Icons.apple_rounded, color: Colors.white, size: 14),
    );
  }
}

/// Séparateur « ou » centré entre deux filets
class AuthDivider extends StatelessWidget {
  final String label;

  const AuthDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AuthColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AuthColors.muted,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AuthColors.border)),
      ],
    );
  }
}
