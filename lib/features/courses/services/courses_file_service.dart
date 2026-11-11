import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

// Service de fichiers du module Cours (couche « Service » — communication
// avec une API externe, conformément à l'architecture imposée) :
// téléverse les PDF de chapitres et les images de couverture vers
// catbox.moe, un hébergeur de fichiers gratuit, sans clé ni compte, qui
// renvoie une URL publique permanente (https://files.catbox.moe/...).
// Aucun coût, aucune configuration de console, aucune facturation.
// Chaque méthode retourne `null` en cas d'échec (réseau, service coupé,
// fichier introuvable) : l'appelant conserve alors son repli historique
// (adresse locale simulée) et l'application reste utilisable.

/// Téléversement de fichiers du module Cours vers l'hébergeur externe.
class CoursesFileService {
  CoursesFileService._();

  /// Instance unique partagée par le wizard et la feuille d'édition.
  static final CoursesFileService instance = CoursesFileService._();

  /// Point d'entrée de l'API d'upload (multipart, sans authentification).
  static const String _endpoint = 'https://catbox.moe/user/api.php';

  /// Domaine attendu dans la réponse, contrôlé avant d'accepter l'URL.
  static const String _hostPrefix = 'https://files.catbox.moe/';

  /// Limites de taille alignées sur les garde-fous de l'interface.
  static const int maxPdfBytes = 20 * 1024 * 1024;
  static const int maxImageBytes = 10 * 1024 * 1024;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 120),
      receiveTimeout: const Duration(seconds: 120),
    ),
  );

  /// Téléverse un PDF de chapitre et retourne son URL publique,
  /// ou `null` si l'envoi est impossible.
  Future<String?> uploadChapterPdf({
    required String courseId,
    required File file,
  }) {
    return _upload(
      file: file,
      fileName: 'chapitre_${DateTime.now().millisecondsSinceEpoch}'
          '_${_safeName(_baseName(file.path))}',
      maxBytes: maxPdfBytes,
    );
  }

  /// Téléverse l'image de couverture d'un cours et retourne son URL,
  /// ou `null` si l'envoi est impossible.
  Future<String?> uploadCoverImage({
    required String courseId,
    required File file,
  }) {
    final name = _baseName(file.path).toLowerCase();
    final isPng = name.endsWith('.png');
    return _upload(
      file: file,
      fileName: 'cover_${DateTime.now().millisecondsSinceEpoch}'
          '${isPng ? '.png' : '.jpg'}',
      maxBytes: maxImageBytes,
    );
  }

  Future<String?> _upload({
    required File file,
    required String fileName,
    required int maxBytes,
  }) async {
    try {
      if (!file.existsSync()) return null;
      if (file.lengthSync() > maxBytes) return null;
      final form = FormData.fromMap({
        'reqtype': 'fileupload',
        'fileToUpload': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
      });
      final response = await _dio.post<String>(_endpoint, data: form);
      final url = (response.data ?? '').trim();
      if (url.startsWith(_hostPrefix)) return url;
      debugPrint('[CoursesFile] Réponse inattendue de l\'hébergeur.');
      return null;
    } catch (error) {
      debugPrint('[CoursesFile] Échec du téléversement : $error');
      return null;
    }
  }

  /// Nom de fichier sans répertoire.
  String _baseName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    return index < 0 ? normalized : normalized.substring(index + 1);
  }

  /// Remplace les caractères problématiques par des tirets (accents,
  /// espaces, ponctuation) pour un nom de fichier distant sûr.
  String _safeName(String name) {
    final cleaned = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    return cleaned.isEmpty ? 'document.pdf' : cleaned;
  }
}
