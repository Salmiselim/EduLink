/// Aides de (dé)sérialisation JSON partagées par les modèles du Forum.

/// Retrouve une valeur d'énumération par son nom, avec une valeur de repli
/// si le nom est absent ou inconnu (données anciennes ou corrompues).
T enumFromName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

/// Lit une date ISO 8601 ; renvoie null si la valeur est absente ou invalide.
DateTime? parseDate(Object? value) {
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Lit une liste de chaînes ; renvoie une liste vide si la valeur est absente.
List<String> parseStringList(Object? value) {
  if (value is List) {
    return value.whereType<String>().toList();
  }
  return <String>[];
}
