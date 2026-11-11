import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Service oEmbed YouTube du module Cours (couche « Service » de
// l'architecture) : à partir d'un lien YouTube, récupère les métadonnées
// PUBLIQUES de la vidéo — titre réel, nom de la chaîne et miniature
// officielle — via l'endpoint oEmbed de YouTube.
// GRATUIT, SANS CLÉ, SANS QUOTA à surveiller (contrairement à Gemini).
// Repli gracieux : toute erreur (hors-ligne, vidéo supprimée ou privée)
// retourne `null` et les écrans conservent leur rendu actuel.

/// Métadonnées publiques d'une vidéo YouTube.
class YouTubeVideoInfo {
  final String videoId;
  final String title;
  final String author;
  final String thumbnailUrl;

  const YouTubeVideoInfo({
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
  });

  /// Lien watch canonique pour ouvrir la vidéo dans l'application YouTube.
  String get watchUrl => 'https://www.youtube.com/watch?v=$videoId';
}

/// Client oEmbed du module Cours.
class YouTubeOEmbedService {
  YouTubeOEmbedService._();

  /// Instance unique partagée par le lecteur et la feuille d'édition.
  static final YouTubeOEmbedService instance = YouTubeOEmbedService._();

  /// Cache mémoire par identifiant de vidéo : évite de redemander oEmbed à
  /// chaque reconstruction d'écran. Une valeur `null` mise en cache signifie
  /// « vidéo non résoluble » (lien invalide, vidéo privée…).
  final Map<String, YouTubeVideoInfo?> _cache = {};

  /// Construit l'URL watch canonique pour ouvrir la vidéo dans
  /// l'application YouTube.
  static String watchUrl(String videoId) =>
      'https://www.youtube.com/watch?v=$videoId';

  /// Extrait l'identifiant d'une vidéo depuis les formats d'URL courants :
  /// `youtube.com/watch?v=…`, `youtu.be/…`, `youtube.com/shorts/…`,
  /// `/embed/…` et `/live/…`. Retourne `null` si l'adresse n'est pas
  /// reconnue comme une vidéo YouTube.
  static String? extractVideoId(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return null;
    final host = uri.host.toLowerCase();
    if (host == 'youtu.be') {
      final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      return id.isEmpty ? null : id;
    }
    if (host.endsWith('youtube.com')) {
      final v = uri.queryParameters['v'];
      if (v != null && v.trim().isNotEmpty) return v.trim();
      final segments = uri.pathSegments;
      if (segments.length >= 2 &&
          (segments.first == 'shorts' ||
              segments.first == 'embed' ||
              segments.first == 'live')) {
        final id = segments[1];
        return id.isEmpty ? null : id;
      }
    }
    return null;
  }

  /// Récupère (et met en cache) les métadonnées de la vidéo référencée par
  /// [videoUrl], ou `null` en cas d'échec ou de lien non reconnu.
  Future<YouTubeVideoInfo?> fetch(String videoUrl) async {
    final id = extractVideoId(videoUrl);
    if (id == null) return null;
    if (_cache.containsKey(id)) return _cache[id];
    try {
      final uri = Uri.https('www.youtube.com', '/oembed', {
        'url': 'https://www.youtube.com/watch?v=$id',
        'format': 'json',
      });
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        // Vidéo supprimée, privée ou lien refusé : garder l'échec en cache
        // pour ne pas marteler l'API à chaque reconstruction.
        _cache[id] = null;
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final title = (data['title'] as String?) ?? '';
      if (title.isEmpty) {
        _cache[id] = null;
        return null;
      }
      final info = YouTubeVideoInfo(
        videoId: id,
        title: title,
        author: (data['author_name'] as String?) ?? '',
        thumbnailUrl: (data['thumbnail_url'] as String?) ??
            'https://i.ytimg.com/vi/$id/hqdefault.jpg',
      );
      _cache[id] = info;
      return info;
    } catch (error) {
      // Échec réseau passager : NE PAS mettre en cache, la prochaine
      // reconstruction d'écran pourra réessayer.
      debugPrint('[YoutubeOEmbed] Échec pour $id : $error');
      return null;
    }
  }
}
