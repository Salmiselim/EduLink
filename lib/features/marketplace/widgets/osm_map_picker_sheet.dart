import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/nominatim_service.dart';

/// Formate une adresse retournée par Nominatim en libellé concis et lisible
/// pour les champs de saisie (ex: "Campus Universitaire de la Manouba, Manouba").
String formatConciseAddress(String displayName) {
  final parts = displayName
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.isEmpty) return displayName.trim();
  if (parts.length == 1) return parts.first;
  final twoParts = '${parts[0]}, ${parts[1]}';
  if (twoParts.length >= 6) return twoParts;
  return parts.take(3).join(', ');
}

/// Feuille modale interactive permettant de chercher une adresse au clavier,
/// de visualiser la carte OpenStreetMap en direct, de cliquer sur la carte
/// pour déplacer le marqueur et de mettre à jour automatiquement le champ d'adresse.
class OsmMapPickerSheet extends StatefulWidget {
  final String initialAddress;
  final String initialCity;
  final double initialLat;
  final double initialLng;
  final ValueChanged<GeocodeResult>? onLocationChanged;

  const OsmMapPickerSheet({
    super.key,
    required this.initialAddress,
    required this.initialCity,
    this.initialLat = 36.8325,
    this.initialLng = 10.1469,
    this.onLocationChanged,
  });

  /// Ouvre le sélecteur de carte en plein écran modal et retourne le [GeocodeResult] validé.
  static Future<GeocodeResult?> show(
    BuildContext context, {
    required String initialAddress,
    required String initialCity,
    double? initialLat,
    double? initialLng,
    ValueChanged<GeocodeResult>? onLocationChanged,
  }) {
    return showModalBottomSheet<GeocodeResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: OsmMapPickerSheet(
          initialAddress: initialAddress,
          initialCity: initialCity,
          initialLat: initialLat ?? 36.8325,
          initialLng: initialLng ?? 10.1469,
          onLocationChanged: onLocationChanged,
        ),
      ),
    );
  }

  @override
  State<OsmMapPickerSheet> createState() => _OsmMapPickerSheetState();
}

class _OsmMapPickerSheetState extends State<OsmMapPickerSheet> {
  final NominatimService _service = const NominatimService();
  final MapController _mapController = MapController();
  late final TextEditingController _searchController;

  late double _lat;
  late double _lng;
  late String _displayName;
  String? _city;
  bool _loading = false;
  double _zoom = 14.5;
  List<GeocodeResult> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _lat = widget.initialLat;
    _lng = widget.initialLng;
    _city = widget.initialCity;
    _displayName = widget.initialAddress.trim().isNotEmpty
        ? '${widget.initialAddress.trim()}, ${widget.initialCity}'
        : 'Campus Universitaire El Manar, Tunis, Tunisie';
    _searchController = TextEditingController(text: widget.initialAddress);
    _loadInitialSuggestions();
  }

  Future<void> _loadInitialSuggestions() async {
    final q = widget.initialAddress.trim();
    final results = await _service.search(
      q.isEmpty ? widget.initialCity : '$q, ${widget.initialCity}',
    );
    if (!mounted) return;
    setState(() {
      _suggestions = results;
      if (q.isNotEmpty && results.isNotEmpty) {
        _lat = results.first.lat;
        _lng = results.first.lng;
        _displayName = results.first.displayName;
        _city = results.first.city ?? _city;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(LatLng(_lat, _lng), _zoom);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _setSearchText(String text) {
    _searchController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Future<void> _runSearch([String? customQuery]) async {
    final query = (customQuery ?? _searchController.text).trim();
    setState(() => _loading = true);
    try {
      final results = await _service.search(query);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        if (results.isNotEmpty) {
          _selectResult(results.first);
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectResult(GeocodeResult result) {
    final concise = formatConciseAddress(result.displayName);
    setState(() {
      _lat = result.lat;
      _lng = result.lng;
      _displayName = result.displayName;
      if (result.city != null) _city = result.city;
      _setSearchText(concise);
    });
    _mapController.move(LatLng(result.lat, result.lng), 15.0);
    widget.onLocationChanged?.call(
      GeocodeResult(
        lat: _lat,
        lng: _lng,
        displayName: concise,
        city: _city,
      ),
    );
  }

  Future<void> _onMapTap(TapPosition tapPosition, LatLng point) async {
    // Mise à jour immédiate du champ de saisie avec les coordonnées pendant la résolution
    final tempLabel =
        'Position (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
    setState(() {
      _lat = point.latitude;
      _lng = point.longitude;
      _displayName = tempLabel;
      _setSearchText(tempLabel);
      _loading = true;
    });
    try {
      final rev = await _service.reverseGeocode(point.latitude, point.longitude);
      if (!mounted) return;
      final concise = formatConciseAddress(rev.displayName);
      setState(() {
        _displayName = rev.displayName;
        if (rev.city != null) _city = rev.city;
        _setSearchText(concise);
      });
      widget.onLocationChanged?.call(
        GeocodeResult(
          lat: _lat,
          lng: _lng,
          displayName: concise,
          city: _city,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Poignée supérieure + En-tête
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.map_rounded,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Carte OpenStreetMap Nominatim',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Tapez une adresse ou touchez la carte pour remplir le champ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(
                  context,
                  GeocodeResult(
                    lat: _lat,
                    lng: _lng,
                    displayName: formatConciseAddress(_displayName),
                    city: _city,
                  ),
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),

        // Barre de recherche d'adresse avec bouton Rechercher
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _runSearch(),
                  decoration: InputDecoration(
                    hintText: 'Ex: Campus Manouba, ESPRIT, INSAT, Sousse...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                              _runSearch('');
                            },
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _loading ? null : () => _runSearch(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.my_location_rounded, size: 18),
                label: const Text('Chercher'),
              ),
            ],
          ),
        ),

        // Suggestions rapides cliquables
        if (_suggestions.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = _suggestions[index];
                final shortLabel = formatConciseAddress(item.displayName);
                final isSelected = (item.lat - _lat).abs() < 0.0005 &&
                    (item.lng - _lng).abs() < 0.0005;
                return ActionChip(
                  avatar: Icon(
                    Icons.place_rounded,
                    size: 16,
                    color: isSelected ? Colors.white : const Color(0xFF2563EB),
                  ),
                  backgroundColor:
                      isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF1E293B),
                  ),
                  label: Text(
                    shortLabel.length > 36
                        ? '${shortLabel.substring(0, 36)}…'
                        : shortLabel,
                  ),
                  onPressed: () => _selectResult(item),
                );
              },
            ),
          ),

        const SizedBox(height: 8),

        // Carte interactive OpenStreetMap
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(_lat, _lng),
                      initialZoom: _zoom,
                      onTap: _onMapTap,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.edulink.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_lat, _lng),
                            width: 56,
                            height: 56,
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFFDC2626),
                              size: 46,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Boutons de zoom + / -
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'osm_zoom_in',
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0F172A),
                          onPressed: () {
                            _zoom = (_zoom + 1).clamp(5.0, 18.0);
                            _mapController.move(LatLng(_lat, _lng), _zoom);
                          },
                          child: const Icon(Icons.add_rounded),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'osm_zoom_out',
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0F172A),
                          onPressed: () {
                            _zoom = (_zoom - 1).clamp(5.0, 18.0);
                            _mapController.move(LatLng(_lat, _lng), _zoom);
                          },
                          child: const Icon(Icons.remove_rounded),
                        ),
                      ],
                    ),
                  ),

                  // Badge coordonnées en haut à gauche
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'GPS : ${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Panneau inférieur : Adresse sélectionnée + Bouton Confirmer
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.place_rounded,
                    color: Color(0xFFDC2626),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () {
                  final customTyped = _searchController.text.trim();
                  final resolvedAddress = customTyped.length >= 6
                      ? customTyped
                      : formatConciseAddress(_displayName);
                  Navigator.pop(
                    context,
                    GeocodeResult(
                      lat: _lat,
                      lng: _lng,
                      displayName: resolvedAddress,
                      city: _city,
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text(
                  'Confirmer cet emplacement sur la carte',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Aperçu de carte OpenStreetMap embarqué directement dans le formulaire ou la fiche détail.
/// Permet aussi de cliquer directement sur la carte pour déplacer le marqueur et
/// mettre à jour le champ d'adresse via [onPointSelected].
class OsmMiniMapPreview extends StatefulWidget {
  final double lat;
  final double lng;
  final String addressLabel;
  final VoidCallback? onTapMap;
  final ValueChanged<GeocodeResult>? onPointSelected;

  const OsmMiniMapPreview({
    super.key,
    required this.lat,
    required this.lng,
    required this.addressLabel,
    this.onTapMap,
    this.onPointSelected,
  });

  @override
  State<OsmMiniMapPreview> createState() => _OsmMiniMapPreviewState();
}

class _OsmMiniMapPreviewState extends State<OsmMiniMapPreview> {
  final NominatimService _service = const NominatimService();
  bool _resolving = false;

  Future<void> _handleTap(TapPosition tapPos, LatLng point) async {
    if (widget.onPointSelected == null) {
      widget.onTapMap?.call();
      return;
    }
    setState(() => _resolving = true);
    try {
      final rev = await _service.reverseGeocode(point.latitude, point.longitude);
      if (!mounted) return;
      widget.onPointSelected!(
        GeocodeResult(
          lat: point.latitude,
          lng: point.longitude,
          displayName: formatConciseAddress(rev.displayName),
          city: rev.city,
        ),
      );
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            FlutterMap(
              key: ValueKey(
                '${widget.lat.toStringAsFixed(4)}_${widget.lng.toStringAsFixed(4)}',
              ),
              options: MapOptions(
                initialCenter: LatLng(widget.lat, widget.lng),
                initialZoom: 14.5,
                onTap: _handleTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.edulink.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(widget.lat, widget.lng),
                      width: 48,
                      height: 48,
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFFDC2626),
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_resolving) ...[
                      const SizedBox(
                        width: 11,
                        height: 11,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      'OpenStreetMap · ${widget.lat.toStringAsFixed(4)}, ${widget.lng.toStringAsFixed(4)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.onTapMap != null)
              Positioned(
                right: 8,
                bottom: 8,
                child: FilledButton.tonalIcon(
                  onPressed: widget.onTapMap,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.94),
                    foregroundColor: const Color(0xFF1E40AF),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.open_in_full_rounded, size: 15),
                  label: const Text(
                    'Ouvrir la carte & chercher',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
