/// Configuration réseau du Forum (M3).
///
/// Les données (questions, réponses, réactions) passent par Cloud Firestore,
/// comme les autres modules (voir `ForumFirestoreService`). Trois API HTTP
/// externes complètent le Forum :
/// - Judge0 CE : exécution des extraits de code (sans clé) ;
/// - Stack Exchange : questions similaires sur Stack Overflow (clé d'application) ;
/// - Gemini : explication d'un code ou d'une erreur (clé API).
///
/// Les clés ne sont jamais écrites dans le code source : elles sont fournies au
/// lancement (`flutter run --dart-define-from-file=dart_defines.json`, voir
/// `FORUM_API.md`). Sans clé, la fonctionnalité concernée se désactive proprement.
class ForumConfig {
  ForumConfig._();

  /// URL de l'API publique Judge0 CE utilisée pour exécuter les extraits de code
  /// (remplace Piston, devenu privé depuis le 15/02/2026).
  static const String judge0BaseUrl = 'https://ce.judge0.com';

  /// API Stack Exchange v2.3 (recherche de questions Stack Overflow).
  static const String stackExchangeBaseUrl = 'https://api.stackexchange.com/2.3';

  /// Clé d'application Stack Exchange (gratuite, https://stackapps.com).
  /// Passe le quota de 300 à 10 000 requêtes par jour.
  static const String stackExchangeKey =
      String.fromEnvironment('STACKEXCHANGE_KEY');

  /// API Gemini (Google AI Studio).
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  /// Modèle Gemini utilisé pour expliquer le code (modifiable avec `GEMINI_MODEL`).
  static const String geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3.5-flash-lite',
  );

  /// Clé API Gemini (https://aistudio.google.com/apikey), envoyée dans l'en-tête
  /// `x-goog-api-key`.
  static const String geminiKey = String.fromEnvironment('GEMINI_API_KEY');
}
