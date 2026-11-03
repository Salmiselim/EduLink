/// Filtre de contenu local appliqué aux questions et réponses.
/// Remplace le filtre de toxicité Perspective API (service arrêté fin 2026) :
/// la détection se fait sur l'appareil, sans envoyer le texte à un tiers.
class ContentFilter {
  ContentFilter._();

  static const List<String> _blockedWords = [
    'idiot',
    'imbecile',
    'cretin',
    'debile',
    'abruti',
    'connard',
    'connasse',
    'salope',
    'merde',
    'putain',
    'fuck',
    'shit',
    'stupid',
    'moron',
    'bastard',
  ];

  static const Map<String, String> _accents = {
    'à': 'a', 'â': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i',
    'ô': 'o', 'ö': 'o',
    'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c',
  };

  static String _normalize(String text) {
    var out = text.toLowerCase();
    _accents.forEach((accent, plain) {
      out = out.replaceAll(accent, plain);
    });
    return out;
  }

  /// Renvoie le premier mot interdit trouvé (mot entier), ou null si le texte est correct.
  static String? findViolation(String text) {
    final words = _normalize(text).split(RegExp(r'[^a-z0-9]+'));
    for (final word in words) {
      if (_blockedWords.contains(word)) return word;
    }
    return null;
  }

  /// Message d'erreur prêt à afficher dans un champ de saisie, ou null.
  static String? validate(String text) {
    return findViolation(text) == null
        ? null
        : 'Merci de rester courtois : ce message contient un mot inapproprié.';
  }
}
