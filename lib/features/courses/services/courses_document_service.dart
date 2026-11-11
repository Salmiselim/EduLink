import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// Service de documents du module Cours (couche « Service » de l'architecture).
// Les fichiers choisis par l'enseignant (galerie / fichiers de l'appareil)
// sont copiés dans le dossier de l'application, puis référencés par un
// chemin RELATIF stocké dans Firestore (`edulink_files/...`).
// L'étudiant peut ensuite :
//  - visualiser le PDF dans l'application (visionneuse intégrée) ;
//  - le « télécharger » via la feuille système (enregistrer/partager).
// Aucune URL externe, aucun service payant : tout reste sur l'appareil.
// Limite assumée du projet académique : sans serveur de fichiers, un
// document n'est lisible que sur l'appareil où il a été importé ; les autres
// appareils affichent un message explicite (voir ChapterReaderScreen).

/// Gestion locale des documents du module Cours.
class CoursesDocumentService {
  CoursesDocumentService._();

  /// Instance unique partagée par les écrans du module.
  static final CoursesDocumentService instance = CoursesDocumentService._();

  /// Préfixe des références locales stockées dans Firestore
  /// (ex. `edulink_files/courses/course_x/1730000000_cours.pdf`).
  static const String localRefPrefix = 'edulink_files/';

  /// Tailles maximales acceptées (garde-fous avant copie).
  static const int maxPdfBytes = 20 * 1024 * 1024;
  static const int maxImageBytes = 10 * 1024 * 1024;

  /// Vrai si [reference] désigne un fichier géré par l'application
  /// (par opposition à une URL distante ou une adresse simulée).
  static bool isLocalReference(String? reference) =>
      reference != null && reference.startsWith(localRefPrefix);

  Directory? _rootCache;

  /// Dossier racine des documents : `<documents de l'app>/edulink_files`.
  Future<Directory?> _root() async {
    final cached = _rootCache;
    if (cached != null) return cached;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final root = Directory(
        '${docs.path}${Platform.pathSeparator}edulink_files',
      );
      if (!root.existsSync()) root.createSync(recursive: true);
      _rootCache = root;
      return root;
    } catch (error) {
      debugPrint('[CoursesDocuments] Dossier local indisponible : $error');
      return null;
    }
  }

  /// Copie un PDF choisi via le sélecteur dans le stockage de l'application
  /// et retourne sa référence relative, ou `null` en cas d'échec.
  Future<String?> importChapterPdf({
    required String courseId,
    required File file,
  }) {
    return _copy(
      picked: file,
      subPath: 'courses/$courseId',
      maxBytes: maxPdfBytes,
      defaultExt: '.pdf',
    );
  }

  /// Copie une image de couverture et retourne sa référence relative,
  /// ou `null` en cas d'échec.
  Future<String?> importCoverImage({
    required String courseId,
    required File file,
  }) {
    final isPng = file.path.toLowerCase().endsWith('.png');
    return _copy(
      picked: file,
      subPath: 'covers',
      maxBytes: maxImageBytes,
      defaultExt: isPng ? '.png' : '.jpg',
    );
  }

  Future<String?> _copy({
    required File picked,
    required String subPath,
    required int maxBytes,
    required String defaultExt,
  }) async {
    try {
      if (!picked.existsSync()) return null;
      if (picked.lengthSync() > maxBytes) return null;
      final root = await _root();
      if (root == null) return null;
      final name =
          '${DateTime.now().millisecondsSinceEpoch}_'
          '${_baseName(picked.path, defaultExt)}';
      final target = Directory(
        '${root.path}${Platform.pathSeparator}'
        '${subPath.replaceAll('/', Platform.pathSeparator)}',
      );
      if (!target.existsSync()) target.createSync(recursive: true);
      final destination = File(
        '${target.path}${Platform.pathSeparator}$name',
      );
      await picked.copy(destination.path);
      return '$localRefPrefix$subPath/$name';
    } catch (error) {
      debugPrint('[CoursesDocuments] Import impossible : $error');
      return null;
    }
  }

  /// Résout une référence locale en [File] réellement présent sur cet
  /// appareil, ou `null` si le fichier est absent (document importé sur
  /// un autre appareil, ou données de démonstration).
  Future<File?> resolveLocalFile(String? reference) async {
    if (!isLocalReference(reference)) return null;
    try {
      final root = await _root();
      if (root == null) return null;
      final relative = reference!.substring(localRefPrefix.length);
      final file = File(
        '${root.path}${Platform.pathSeparator}'
        '${relative.replaceAll('/', Platform.pathSeparator)}',
      );
      return file.existsSync() ? file : null;
    } catch (error) {
      debugPrint('[CoursesDocuments] Résolution impossible : $error');
      return null;
    }
  }

  /// « Téléchargement » d'un document : ouvre la feuille système
  /// d'enregistrement/partage afin que l'utilisateur choisisse la
  /// destination (Téléchargements, Drive, e-mail…).
  Future<bool> exportDocument(File file, {required String title}) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          title: title,
          text: 'Document EduLink : $title',
        ),
      );
      return true;
    } catch (error) {
      debugPrint('[CoursesDocuments] Partage impossible : $error');
      return false;
    }
  }

  /// Nom de fichier final : nettoyé, en minuscules, extension garantie.
  String _baseName(String path, String defaultExt) {
    final normalized = path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    var name = index < 0 ? normalized : normalized.substring(index + 1);
    name = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    if (!name.contains('.')) name += defaultExt;
    return name;
  }
}
