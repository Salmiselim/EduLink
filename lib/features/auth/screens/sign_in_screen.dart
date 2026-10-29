import 'package:flutter/material.dart';
import '../../../main.dart';
import '../widgets/auth_ui.dart';
import 'forgot_password_screen.dart';
import 'sign_up_screen.dart';

// ============================================================================
// ÉCRAN DE CONNEXION (SignInScreen) — interface de démonstration.
// Aucun backend : toute combinaison e-mail / mot de passe au format valide
// ouvre l'application, et le bouton « Passer » permet de tester librement
// sans compte. La connexion réelle (Firebase Authentication) sera branchée
// par le module Comptes & Profils.
// ============================================================================

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscure = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Ouvre l'application (shell intégré) en remplaçant toute la pile.
  /// [message] : facultatif, affiché en SnackBar sur l'écran suivant.
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

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _enterApp(message: 'Bienvenue sur EduLink ! (mode démonstration)');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.scaffold,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Passer — accès direct à l'application pour tester
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
                const AuthHeader(subtitle: 'Apprendre, échanger, progresser'),
                const SizedBox(height: 28),
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
                Row(
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
                    const Spacer(),
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
                AuthPrimaryButton(label: 'Se connecter', onPressed: _submit),
                const SizedBox(height: 22),
                const AuthDivider(label: 'ou continuer avec'),
                const SizedBox(height: 14),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
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
