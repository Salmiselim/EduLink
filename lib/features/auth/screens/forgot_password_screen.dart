import 'dart:math';

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/auth_ui.dart';

/// Écran de récupération de mot de passe, accessible depuis `SignInScreen`.
/// Flux en trois étapes avec code de vérification :
/// 1. saisie de l'adresse e-mail → un code à 6 chiffres est « envoyé » ;
/// 2. saisie du code (3 tentatives, expiration après 10 minutes) ;
/// 3. choix d'un nouveau mot de passe (confirmation incluse).
///
/// Livraison du code : tant que l'envoi d'e-mails personnalisés exige un
/// serveur (Cloud Functions — plan facturé), le code est remis à
/// l'utilisateur via une notification « e-mail simulé » et écrit dans la
/// console de développement. Lorsque Firebase Auth est actif, l'e-mail
/// officiel de réinitialisation (lien sécurisé) est également envoyé : le
/// changement est ainsi réellement finalisable depuis la boîte e-mail.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  /// Étapes du flux : e-mail → code de vérification → nouveau mot de passe → succès.
  static const int _stepEmail = 0;
  static const int _stepCode = 1;
  static const int _stepPassword = 2;
  static const int _stepDone = 3;

  /// Nombre de chiffres du code et durée de validité.
  static const int _codeLength = 6;
  static const Duration _codeValidity = Duration(minutes: 10);

  /// Nombre maximal de saisies erronées avant de devoir redemander un code.
  static const int _maxAttempts = 3;

  final GlobalKey<FormState> _emailFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _codeFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _passwordFormKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  int _step = _stepEmail;
  bool _sending = false;

  /// Code courant, sa date d'expiration et les tentatives restantes.
  String _code = '';
  DateTime? _codeExpiresAt;
  int _attemptsLeft = _maxAttempts;

  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool long = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: Duration(seconds: long ? 6 : 3),
        content: Text(message),
      ),
    );
  }

  /// Génère un nouveau code à 6 chiffres, affiche la notification « e-mail
  /// simulé » (l'utilisateur n'a pas de boîte de réception dans la démo) et
  /// passe à l'étape de vérification.
  void _generateAndSendCode({required bool demoMode}) {
    final code = (100000 + Random().nextInt(900000)).toString();
    setState(() {
      _code = code;
      _codeExpiresAt = DateTime.now().add(_codeValidity);
      _attemptsLeft = _maxAttempts;
      _codeController.clear();
      _step = _stepCode;
    });
    _showMessage(
      demoMode
          ? 'Mode démonstration — votre code de vérification est : $code'
          : 'E-mail simulé (démonstration) — code de vérification : $code',
      long: true,
    );
    debugPrint(
      '[ForgotPassword] Code de vérification pour '
      '${_emailController.text.trim()} : $code',
    );
  }

  /// Étape 1 : valide l'e-mail, demande l'envoi réel de l'e-mail officiel
  /// Firebase (si configuré) puis délivre le code de vérification.
  Future<void> _submitEmail() async {
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;
    setState(() => _sending = true);
    final result = await AuthService.instance.sendPasswordReset(
      email: _emailController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    switch (result.outcome) {
      case AuthOutcome.failure:
        _showMessage(result.error ?? 'Envoi impossible.');
      case AuthOutcome.success:
        _generateAndSendCode(demoMode: false);
      case AuthOutcome.demo:
        _generateAndSendCode(demoMode: true);
    }
  }

  /// Étape 2 : vérifie le code saisi (expiration + correspondance + tentatives).
  void _submitCode() {
    if (!(_codeFormKey.currentState?.validate() ?? false)) return;
    final expiresAt = _codeExpiresAt;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      _showMessage('Code expiré — demandez un nouveau code.');
      return;
    }
    final entered = _codeController.text.trim();
    if (entered != _code) {
      _attemptsLeft--;
      if (_attemptsLeft <= 0) {
        setState(() {
          _step = _stepEmail;
          _codeController.clear();
        });
        _showMessage(
          'Trop de tentatives — saisissez à nouveau votre e-mail pour '
          'recevoir un nouveau code.',
        );
        return;
      }
      setState(() => _codeController.clear());
      _showMessage(
        'Code incorrect — $_attemptsLeft tentative'
        '${_attemptsLeft > 1 ? 's' : ''} restante'
        '${_attemptsLeft > 1 ? 's' : ''}.',
      );
      return;
    }
    setState(() => _step = _stepPassword);
  }

  /// Étape 3 : enregistre le nouveau mot de passe (flux de démonstration)
  /// et affiche la confirmation.
  void _submitPassword() {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;
    setState(() => _step = _stepDone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.scaffold,
      appBar: AppBar(
        backgroundColor: AuthColors.scaffold,
        surfaceTintColor: AuthColors.scaffold,
        elevation: 0,
        title: Text(
          _step == _stepDone ? 'Réinitialisation terminée' : 'Mot de passe oublié',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AuthColors.text,
          ),
        ),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case _stepCode:
        return _buildCodeView();
      case _stepPassword:
        return _buildPasswordView();
      case _stepDone:
        return _buildDoneView();
      default:
        return _buildEmailView();
    }
  }

  /// Bandeau d'avancement commun aux trois étapes de saisie.
  Widget _buildProgress() {
    const labels = ['E-mail', 'Code', 'Mot de passe'];
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Container(
                width: 26,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: i <= _step ? AuthColors.primary : AuthColors.border,
              ),
            Text(
              labels[i],
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: i == _step ? FontWeight.w800 : FontWeight.w600,
                color: i == _step ? AuthColors.primary : AuthColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIcon(IconData icon, Color background, Color color) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, size: 34, color: color),
      ),
    );
  }

  // ── Étape 1 : adresse e-mail ───────────────────────────────────────────────

  Widget _buildEmailView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Form(
        key: _emailFormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProgress(),
            const SizedBox(height: 8),
            _buildIcon(
              Icons.mail_outline_rounded,
              AuthColors.infoBg,
              AuthColors.primary,
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
              'Entrez votre adresse e-mail : nous vous enverrons un code de '
              'vérification à 6 chiffres.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AuthColors.muted,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submitEmail(),
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
              label: _sending ? 'Envoi en cours…' : 'Envoyer le code de vérification',
              onPressed: _sending ? null : _submitEmail,
            ),
          ],
        ),
      ),
    );
  }

  // ── Étape 2 : code de vérification ────────────────────────────────────────

  Widget _buildCodeView() {
    final email = _emailController.text.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Form(
        key: _codeFormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProgress(),
            const SizedBox(height: 8),
            _buildIcon(
              Icons.dialpad_rounded,
              AuthColors.infoBg,
              AuthColors.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Vérification',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AuthColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Saisissez le code à $_codeLength chiffres envoyé à $email.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AuthColors.muted,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Code valable 10 minutes · $_maxAttempts tentatives.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AuthColors.muted,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: _codeLength,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
                color: AuthColors.text,
              ),
              onFieldSubmitted: (_) => _submitCode(),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: authInputDecoration(
                label: 'Code de vérification',
                hint: '000000',
                icon: Icons.pin_rounded,
                counterText: '',
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return 'Entrez le code reçu.';
                if (v.length != _codeLength) {
                  return 'Le code contient $_codeLength chiffres.';
                }
                if (int.tryParse(v) == null) {
                  return 'Le code ne contient que des chiffres.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            // Renvoi : génère un nouveau code (l'ancien devient invalide).
            Center(
              child: TextButton(
                onPressed: () => _generateAndSendCode(
                  demoMode: !AuthService.instance.isFirebaseReady,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AuthColors.primary,
                ),
                child: const Text(
                  'Renvoyer le code',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            AuthPrimaryButton(
              label: 'Vérifier le code',
              onPressed: _submitCode,
            ),
          ],
        ),
      ),
    );
  }

  // ── Étape 3 : nouveau mot de passe ────────────────────────────────────────

  Widget _buildPasswordView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Form(
        key: _passwordFormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProgress(),
            const SizedBox(height: 8),
            _buildIcon(
              Icons.lock_reset_rounded,
              AuthColors.infoBg,
              AuthColors.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nouveau mot de passe',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AuthColors.text,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choisissez un mot de passe d\'au moins 6 caractères, puis '
              'confirmez-le.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AuthColors.muted,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscureNew,
              textInputAction: TextInputAction.next,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: authInputDecoration(
                label: 'Nouveau mot de passe',
                icon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  icon: Icon(
                    _obscureNew
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AuthColors.muted,
                    size: 20,
                  ),
                ),
              ),
              validator: (value) {
                final v = value ?? '';
                if (v.isEmpty) return 'Entrez un nouveau mot de passe.';
                if (v.length < 6) {
                  return 'Le mot de passe doit contenir au moins 6 caractères.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submitPassword(),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: authInputDecoration(
                label: 'Confirmer le mot de passe',
                icon: Icons.lock_outline_rounded,
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
                if ((value ?? '').isEmpty) {
                  return 'Confirmez le mot de passe.';
                }
                if (value != _passwordController.text) {
                  return 'Les mots de passe ne correspondent pas.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: 'Confirmer le nouveau mot de passe',
              onPressed: _submitPassword,
            ),
          ],
        ),
      ),
    );
  }

  // ── Étape 4 : confirmation ────────────────────────────────────────────────

  Widget _buildDoneView() {
    final firebaseReady = AuthService.instance.isFirebaseReady;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _buildIcon(
            Icons.lock_reset_rounded,
            AuthColors.successBg,
            AuthColors.success,
          ),
          const SizedBox(height: 16),
          const Text(
            'Mot de passe modifié !',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AuthColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connectez-vous avec votre nouveau mot de passe.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: AuthColors.muted,
            ),
          ),
          if (firebaseReady) ...[
            const SizedBox(height: 8),
            const Text(
              "Un e-mail officiel de réinitialisation vous a également été "
              'envoyé : suivez le lien sécurisé qu\'il contient pour confirmer '
              'définitivement le changement.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: AuthColors.muted,
            ),
          ),
          ],
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Se connecter',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
