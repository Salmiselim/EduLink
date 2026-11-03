/// Configuration réseau du Forum (M3).
///
/// Les données (questions, réponses, réactions) passent par Cloud Firestore,
/// comme les autres modules (voir `ForumFirestoreService`). Seule l'exécution
/// de code utilise une API HTTP externe : Judge0 CE.
class ForumConfig {
  ForumConfig._();

  /// URL de l'API publique Judge0 CE utilisée pour exécuter les extraits de code
  /// (remplace Piston, devenu privé depuis le 15/02/2026).
  static const String judge0BaseUrl = 'https://ce.judge0.com';
}
