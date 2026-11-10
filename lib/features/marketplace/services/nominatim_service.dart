import 'dart:convert';

import 'package:http/http.dart' as http;

/// Résultat d'un géocodage : position GPS et adresse normalisée par OpenStreetMap.
class GeocodeResult {
  final double lat;
  final double lng;
  final String displayName;
  final String? city;

  const GeocodeResult({
    required this.lat,
    required this.lng,
    required this.displayName,
    this.city,
  });
}

/// Client de l'API publique OpenStreetMap Nominatim (gratuite, sans clé).
/// Transforme une adresse saisie en coordonnées GPS et inversement (reverse geocoding),
/// avec repli local instantané sur les campus et villes de Tunisie si le réseau de l'émulateur bloque.
class NominatimService {
  const NominatimService();

  /// Nominatim exige un `User-Agent` HTTP explicite.
  static const Map<String, String> _headers = {
    'User-Agent': 'EduLinkMarketplace/1.0 (https://edulink.tn; contact@edulink.tn)',
    'Accept': 'application/json',
    'Accept-Language': 'fr,en',
  };

  /// Base locale de secours des principaux campus et villes universitaires tunisiens
  /// garantissant une réponse immédiate même si l'émulateur a une coupure DNS.
  static const List<GeocodeResult> _tunisianLandmarks = [
    GeocodeResult(
      lat: 36.8131,
      lng: 10.0639,
      city: 'Manouba',
      displayName: 'Campus Universitaire de la Manouba (ENSI / ISAMM / FSEG), Manouba, Tunisie',
    ),
    GeocodeResult(
      lat: 36.8992,
      lng: 10.1895,
      city: 'Ariana',
      displayName: 'Pôle Technologique El Ghazala (ESPRIT / SUP\'COM), Ariana, Tunisie',
    ),
    GeocodeResult(
      lat: 36.8428,
      lng: 10.1969,
      city: 'Tunis',
      displayName: 'INSAT - Centre Urbain Nord, Tunis, Tunisie',
    ),
    GeocodeResult(
      lat: 36.8325,
      lng: 10.1469,
      city: 'Tunis',
      displayName: 'Campus Universitaire El Manar (FST / ENIT / FDSP), Tunis, Tunisie',
    ),
    GeocodeResult(
      lat: 36.8002,
      lng: 10.1860,
      city: 'Tunis',
      displayName: 'Avenue Habib Bourguiba, Centre-Ville, Tunis, Tunisie',
    ),
    GeocodeResult(
      lat: 36.8625,
      lng: 10.1956,
      city: 'Ariana',
      displayName: 'Ariana Centre, Gouvernorat de l\'Ariana, Tunisie',
    ),
    GeocodeResult(
      lat: 35.8256,
      lng: 10.6084,
      city: 'Sousse',
      displayName: 'Campus Universitaire de Sousse (ISSAT / FSEG), Sousse, Tunisie',
    ),
    GeocodeResult(
      lat: 34.7406,
      lng: 10.7603,
      city: 'Sfax',
      displayName: 'Campus Universitaire de Sfax (ENIS / FSEGS), Sfax, Tunisie',
    ),
    GeocodeResult(
      lat: 35.7643,
      lng: 10.8113,
      city: 'Monastir',
      displayName: 'Campus Universitaire de Monastir (FSM / ENIM), Monastir, Tunisie',
    ),
  ];

  /// Recherche une liste de lieux correspondant à [query] via OpenStreetMap Nominatim.
  Future<List<GeocodeResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return _tunisianLandmarks;

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': trimmed,
        'format': 'json',
        'addressdetails': '1',
        'limit': '5',
        'countrycodes': 'tn',
      });

      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        if (data.isNotEmpty) {
          return data.map((item) {
            final map = item as Map<String, dynamic>;
            final address = map['address'] as Map<String, dynamic>?;
            final detectedCity = (address?['city'] ??
                    address?['town'] ??
                    address?['state'] ??
                    address?['county'])
                as String?;
            return GeocodeResult(
              lat: double.parse(map['lat'] as String),
              lng: double.parse(map['lon'] as String),
              displayName: map['display_name'] as String? ?? trimmed,
              city: _normalizeTunisianCity(detectedCity ?? map['display_name'] as String? ?? ''),
            );
          }).toList();
        }
      }
    } catch (_) {
      // En cas de blocage réseau sur l'émulateur, on bascule sur la recherche locale
    }

    // Filtrage dans la base de secours tunisienne
    final qLower = trimmed.toLowerCase();
    final matches = _tunisianLandmarks.where((loc) {
      return loc.displayName.toLowerCase().contains(qLower) ||
          (loc.city?.toLowerCase().contains(qLower) ?? false);
    }).toList();

    if (matches.isNotEmpty) return matches;

    // Si aucun mot-clé précis ne correspond, génère une position centrée sur la ville détectée
    final fallbackCity = _normalizeTunisianCity(trimmed) ?? 'Tunis';
    final base = _tunisianLandmarks.firstWhere(
      (l) => l.city == fallbackCity,
      orElse: () => _tunisianLandmarks[3],
    );
    return [
      GeocodeResult(
        lat: base.lat,
        lng: base.lng,
        city: fallbackCity,
        displayName: '$trimmed, $fallbackCity, Tunisie',
      ),
    ];
  }

  /// Retourne la meilleure correspondance pour [query].
  Future<GeocodeResult?> geocode(String query) async {
    final results = await search(query);
    return results.isEmpty ? null : results.first;
  }

  /// Géocodage inverse (Reverse Geocoding) : convertit un clic sur la carte (`lat`, `lng`)
  /// en adresse postale lisible via OpenStreetMap Nominatim.
  Future<GeocodeResult> reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': lat.toString(),
        'lon': lng.toString(),
        'format': 'json',
        'addressdetails': '1',
      });

      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName = map['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          final address = map['address'] as Map<String, dynamic>?;
          final rawCity = (address?['city'] ??
                  address?['town'] ??
                  address?['state'] ??
                  displayName)
              as String;
          return GeocodeResult(
            lat: lat,
            lng: lng,
            displayName: displayName,
            city: _normalizeTunisianCity(rawCity),
          );
        }
      }
    } catch (_) {
      // Repli vers le point de repère le plus proche
    }

    // Recherche du point connu le plus proche
    GeocodeResult closest = _tunisianLandmarks.first;
    double bestDist = double.infinity;
    for (final item in _tunisianLandmarks) {
      final d = (item.lat - lat) * (item.lat - lat) + (item.lng - lng) * (item.lng - lng);
      if (d < bestDist) {
        bestDist = d;
        closest = item;
      }
    }
    return GeocodeResult(
      lat: lat,
      lng: lng,
      city: closest.city,
      displayName: 'Point sélectionné près de ${closest.city} (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})',
    );
  }

  static String? _normalizeTunisianCity(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('manouba')) return 'Manouba';
    if (lower.contains('ariana') || lower.contains('ghazala')) return 'Ariana';
    if (lower.contains('sousse')) return 'Sousse';
    if (lower.contains('sfax')) return 'Sfax';
    if (lower.contains('monastir')) return 'Monastir';
    if (lower.contains('tunis') || lower.contains('manar') || lower.contains('insat')) {
      return 'Tunis';
    }
    return null;
  }
}
