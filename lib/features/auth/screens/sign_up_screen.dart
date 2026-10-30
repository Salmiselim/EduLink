import 'package:flutter/material.dart';
import '../../../main.dart';
import '../widgets/auth_ui.dart';
import 'sign_in_screen.dart';

/// Rôle de compte sélectionné lors de l'inscription.
enum _AccountRole { student, teacher }

/// Écran de création de compte avec sélection du profil (étudiant ou enseignant)
/// et validation complète des champs avant ouverture du shell `EduLinkShell`.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  /// Clé globale pilotant l'état et la validation du formulaire d'inscription.
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Contrôleurs associés aux champs texte du formulaire.
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  /// Rôle actif déterminant l'affichage conditionnel du champ code établissement.
  _AccountRole _role = _AccountRole.student;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _acceptTerms = false;

  @override
  void dispose() {
    // Nettoyage de tous les contrôleurs de texte lors du démontage du widget.
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// Valide le formulaire et l'acceptation des conditions générales, affiche un
  /// retour par `SnackBar` puis remplace toute la pile de navigation vers `EduLinkShell`.
  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Text("Veuillez accepter les conditions d'utilisation."),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 2),
        content: Text('Compte créé — bienvenue ! (mode démonstration)'),
      ),
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const EduLinkShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTeacher = _role == _AccountRole.teacher;

    // Scaffold structurant la barre supérieure et le corps du formulaire d'inscription.
    return Scaffold(
      backgroundColor: AuthColors.scaffold,
      appBar: AppBar(
        backgroundColor: AuthColors.scaffold,
        surfaceTintColor: AuthColors.scaffold,
        elevation: 0,
        title: const Text(
          'Créer un compte',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AuthColors.text,
          ),
        ),
      ),
      // SafeArea + SingleChildScrollView pour garantir un défilement fluide avec le clavier.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthHeader(subtitle: 'Rejoignez la communauté EduLink'),
                const SizedBox(height: 26),
                // Champ du nom complet avec contrôle de longueur minimale et maximale.
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: authInputDecoration(
                    label: 'Nom complet',
                    hint: 'Ex. Oumayma Brineg',
                    icon: Icons.person_outline_rounded,
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.length < 3 || v.length > 60) {
                      return 'Entre 3 et 60 caractères.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                // Champ d'adresse e-mail validant la présence des séparateurs de domaine.
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: authInputDecoration(
                    label: 'Adresse e-mail',
                    hint: 'prenom.nom@exemple.tn',
                    icon: Icons.mail_outline_rounded,
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Entrez votre adresse e-mail.';
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Entrez une adresse e-mail valide.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                // Champ du mot de passe principal avec bascule d'affichage et seuil à 6 caractères.
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: authInputDecoration(
                    label: 'Mot de passe',
                    icon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AuthColors.muted,
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final v = value ?? '';
                    if (v.length < 6) return 'Au moins 6 caractères.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                // Champ de confirmation vérifiant la correspondance exacte avec `_passwordController`.
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.next,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: authInputDecoration(
                    label: 'Confirmer le mot de passe',
                    icon: Icons.lock_reset_outlined,
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AuthColors.muted,
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Les mots de passe ne correspondent pas.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                const Text(
                  'Je suis...',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AuthColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                // Sélecteur de profil partagé en deux colonnes égales grâce à `Expanded`.
                Row(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        selected: _role == _AccountRole.student,
                        icon: Icons.school_outlined,
                        label: 'Étudiant',
                        subtitle: 'Suivre des cours',
                        onTap: () =>
                            setState(() => _role = _AccountRole.student),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RoleCard(
                        selected: isTeacher,
                        icon: Icons.verified_outlined,
                        label: 'Enseignant',
                        subtitle: 'Publier des cours',
                        onTap: () =>
                            setState(() => _role = _AccountRole.teacher),
                      ),
                    ),
                  ],
                ),
                // Champ supplémentaire requis uniquement lorsque le rôle enseignant est sélectionné.
                if (isTeacher) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _codeController,
                    textInputAction: TextInputAction.done,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: authInputDecoration(
                      label: 'Code établissement',
                      hint: 'Ex. ESPRIT-2026',
                      icon: Icons.badge_outlined,
                      helperText: 'Code fourni par votre établissement',
                    ),
                    validator: (value) {
                      if (!isTeacher) return null;
                      final v = value?.trim() ?? '';
                      if (v.length < 4) {
                        return 'Code à au moins 4 caractères.';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                // Case d'acceptation des conditions accompagnée d'un libellé flexible (`Expanded`).
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _acceptTerms,
                        onChanged: (value) =>
                            setState(() => _acceptTerms = value ?? false),
                        activeColor: AuthColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        side: const BorderSide(color: AuthColors.border),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "J'accepte les conditions d'utilisation et la "
                        'politique de confidentialité d\'EduLink.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: AuthColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AuthPrimaryButton(label: 'Créer un compte', onPressed: _submit),
                const SizedBox(height: 22),
                // Bascule vers `SignInScreen` via `Navigator.pushReplacement`.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Déjà un compte ?',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AuthColors.muted,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignInScreen(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AuthColors.primary,
                      ),
                      child: const Text(
                        'Se connecter',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte cliquable représentant un rôle utilisateur (étudiant ou enseignant)
/// avec mise en évidence visuelle de la sélection active.
class _RoleCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.selected,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AuthColors.infoBg : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AuthColors.primary : AuthColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? AuthColors.primary : AuthColors.muted,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected ? AuthColors.primary : AuthColors.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AuthColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
