import 'package:flutter/material.dart';
import '../../../main.dart';
import '../widgets/auth_ui.dart';
import 'forgot_password_screen.dart';
import 'sign_up_screen.dart';

/// Écran de connexion de l'application EduLink.
/// Valide le format des identifiants localement avant d'ouvrir le shell
/// principal `EduLinkShell` (mode démonstration en attente de Firebase Auth).
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  /// Clé globale permettant d'exécuter la validation groupée du widget `Form`.
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Contrôleurs récupérant les valeurs saisies dans les champs e-mail et mot de passe.
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  /// Contrôle l'affichage masqué ou en clair du mot de passe.
  bool _obscure = true;

  /// État de la case à cocher de mémorisation de session.
  bool _rememberMe = false;

  @override
  void dispose() {
    // Libération des contrôleurs de saisie à la destruction de l'écran.
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Affiche éventuellement un [SnackBar] d'information puis redirige vers
  /// `EduLinkShell` via `Navigator.pushAndRemoveUntil` en vidant toute la pile
  /// de navigation pour empêcher un retour arrière vers l'authentification.
  void _enterApp({String? message}) {
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(duration: const Duration(seconds: 2), content: Text(message)),
      );
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const EduLinkShell()),
      (route) => false,
    );
  }

  /// Déclenche la validation des `TextFormField` avant d'autoriser l'entrée dans l'application.
  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _enterApp(message: 'Bienvenue sur EduLink ! (mode démonstration)');
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold fournissant la structure visuelle de base de l'écran de connexion.
    return Scaffold(
      backgroundColor: AuthColors.scaffold,
      // SafeArea évite le chevauchement avec la barre d'état et les encoches système.
      body: SafeArea(
        // SingleChildScrollView évite les erreurs de dépassement à l'ouverture du clavier.
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          // Formulaire relié à `_formKey` avec validation dynamique au fil de la saisie.
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Accès rapide permettant d'ouvrir directement le shell principal sans saisie.
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _enterApp(),
                    style: TextButton.styleFrom(
                      foregroundColor: AuthColors.muted,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text(
                      'Passer',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // En-tête de marque partagé entre les écrans d'authentification.
                const AuthHeader(subtitle: 'Apprendre, échanger, progresser'),
                const SizedBox(height: 28),
                // Champ e-mail validé en temps réel via `AutovalidateMode.onUserInteraction`.
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
                // Champ mot de passe avec bouton de visibilité et validation de longueur minimale.
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
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
                    if (v.isEmpty) return 'Entrez votre mot de passe.';
                    if (v.length < 6) {
                      return 'Au moins 6 caractères.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                // Ligne regroupant l'option de maintien de session et le lien de récupération.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (value) =>
                                setState(() => _rememberMe = value ?? false),
                            activeColor: AuthColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            side: const BorderSide(color: AuthColors.border),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _rememberMe = !_rememberMe),
                          child: const Text(
                            'Se souvenir de moi',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AuthColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Empile `ForgotPasswordScreen` sur le navigateur courant.
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AuthColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: const Text(
                        'Mot de passe oublié ?',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Bouton principal déclenchant la validation et la connexion.
                AuthPrimaryButton(label: 'Se connecter', onPressed: _submit),
                const SizedBox(height: 22),
                const AuthDivider(label: 'ou continuer avec'),
                const SizedBox(height: 14),
                // Boutons de connexion tierce répartis sur toute la largeur via `Expanded`.
                Row(
                  children: [
                    Expanded(
                      child: AuthSocialButton(
                        logo: const GoogleLogo(),
                        label: 'Google',
                        onPressed: () => _enterApp(
                          message: 'Connexion avec Google — mode démonstration',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AuthSocialButton(
                        logo: const AppleLogo(),
                        label: 'Apple',
                        onPressed: () => _enterApp(
                          message: 'Connexion avec Apple — mode démonstration',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                // Redirection vers `SignUpScreen` par remplacement de la route active.
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Pas encore de compte ?',
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
                            builder: (_) => const SignUpScreen(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AuthColors.primary,
                      ),
                      child: const Text(
                        'Créer un compte',
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
