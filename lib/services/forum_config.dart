/// Configuration réseau du Forum (M3).
///
/// Le CRUD est toujours enregistré en local (SharedPreferences). La synchronisation
/// REST vers le backend NestJS est désactivée par défaut ; pour l'activer :
///
/// ```
/// flutter run --dart-define=FORUM_REMOTE=true
/// flutter run --dart-define=FORUM_REMOTE=true --dart-define=FORUM_API_URL=http://192.168.1.20:3000
/// ```
///
/// `10.0.2.2` est l'adresse de l'ordinateur hôte vue depuis l'émulateur Android.
/// Un serveur de démonstration est fourni : `node tools/forum_mock_server.js`.
class ForumConfig {
  /// Active la synchronisation REST (push à chaque modification, pull au rafraîchissement).
  final bool remoteEnabled;

  /// URL de base de l'API REST du Forum (sans `/` final).
  final String baseUrl;

  /// Jeton Bearer optionnel (jeton ID Firebase vérifié par l'AuthGuard NestJS).
  final String? authToken;

  /// Délai maximal d'une requête REST.
  final Duration timeout;

  const ForumConfig({
    this.remoteEnabled = false,
    this.baseUrl = 'http://10.0.2.2:3000',
    this.authToken,
    this.timeout = const Duration(seconds: 6),
  });

  /// Configuration lue depuis les `--dart-define` au lancement.
  static const ForumConfig fromEnv = ForumConfig(
    remoteEnabled: bool.fromEnvironment('FORUM_REMOTE'),
    baseUrl: String.fromEnvironment(
      'FORUM_API_URL',
      defaultValue: 'http://10.0.2.2:3000',
    ),
  );

  /// URL de l'API publique Judge0 CE utilisée pour exécuter les extraits de code
  /// (remplace Piston, devenu privé depuis le 15/02/2026).
  static const String judge0BaseUrl = 'https://ce.judge0.com';
}
