import 'package:flutter/material.dart';
import '../widgets/auth_ui.dart';

/// Écran de récupération de mot de passe accessible depuis `SignInScreen`.
/// Bascule vers un écran de confirmation une fois l'adresse e-mail validée.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  /// Clé globale associée au `Form` pour valider le champ e-mail avant envoi.
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Contrôleur du champ d'adresse e-mail, utilisé aussi dans l'écran de confirmation.
  final TextEditingController _emailController = TextEditingController();

  /// Indique si la demande de réinitialisation a été soumise.
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Vérifie la validité du formulaire puis affiche la vue de confirmation.
  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    // Structure `Scaffold` + `SafeArea` alternant entre saisie et confirmation selon `_sent`.
    return Scaffold(
      backgroundColor: AuthColors.scaffold,
      appBar: AppBar(
        backgroundColor: AuthColors.scaffold,
        surfaceTintColor: AuthColors.scaffold,
        elevation: 0,
        title: const Text(
          'Mot de passe oublié',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AuthColors.text,
          ),
        ),
      ),
      body: SafeArea(
        child: _sent ? _buildSentView() : _buildFormView(),
      ),
    );
  }

  /// Construit la vue contenant le formulaire de saisie de l'adresse e-mail.
  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AuthColors.infoBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mail_outline_rounded,
                  size: 34,
                  color: AuthColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Réinitialiser votre mot de passe',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AuthColors.text,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Entrez votre adresse e-mail : nous vous enverrons un lien '
              'pour créer un nouveau mot de passe.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AuthColors.muted,
              ),
            ),
            const SizedBox(height: 24),
            // Champ e-mail avec validation automatique dès la première modification.
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
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
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: 'Envoyer le lien de réinitialisation',
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  /// Construit la vue récapitulative affichée après validation de l'adresse e-mail.
  Widget _buildSentView() {
    final email = _emailController.text.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AuthColors.successBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mark_email_read_rounded,
                size: 34,
                color: AuthColors.success,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Lien envoyé !',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AuthColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Si un compte existe pour $email, vous recevrez un lien de "
            'réinitialisation dans quelques minutes. Pensez à vérifier '
            'votre dossier de courriers indésirables.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: AuthColors.muted,
            ),
          ),
          const SizedBox(height: 24),
          // Dépile `ForgotPasswordScreen` pour revenir à `SignInScreen`.
          AuthPrimaryButton(
            label: 'Retour à la connexion',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
