/// Règles sur les tags d'une question (saisis séparés par des virgules ou des espaces).
const int kMaxTags = 5;
const int kMinTagLength = 2;
const int kMaxTagLength = 20;

/// Découpe « flutter, #Provider état » en `['flutter', 'provider', 'état']` :
/// minuscules, sans `#`, sans doublon, ordre conservé.
List<String> parseTags(String raw) {
  final seen = <String>{};
  final result = <String>[];
  for (final part in raw.split(RegExp(r'[,;\s]+'))) {
    var tag = part.trim().toLowerCase();
    while (tag.startsWith('#')) {
      tag = tag.substring(1);
    }
    if (tag.isEmpty) continue;
    if (seen.add(tag)) result.add(tag);
  }
  return result;
}

/// Renvoie un message d'erreur si les tags saisis sont invalides, sinon null.
String? validateTags(String raw) {
  final tags = parseTags(raw);
  if (tags.length > kMaxTags) return 'Maximum $kMaxTags tags';
  for (final tag in tags) {
    if (tag.length < kMinTagLength) {
      return 'Chaque tag doit contenir au moins $kMinTagLength caractères';
    }
    if (tag.length > kMaxTagLength) {
      return 'Un tag ne peut pas dépasser $kMaxTagLength caractères';
    }
  }
  return null;
}
