import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

// Visionneuse vidéo intégrée du module Cours : joue une vidéo YouTube DANS
// l'application (lecteur officiel iFrame de YouTube, sans clé d'API), en
// plein écran, sur le modèle de la visionneuse PDF (`PdfViewerScreen`).
// Android, iOS et Web uniquement — l'accès est gardé par l'appelant
// (`ChapterReaderScreen`), qui vérifie la plateforme avant de pousser cet
// écran et propose l'ouverture externe dans YouTube sur les autres
// plateformes (bureau sans WebView).

/// Lecteur plein écran d'une vidéo YouTube intégrée à l'application.
class YouTubePlayerScreen extends StatefulWidget {
  /// Identifiant de la vidéo (`extractVideoId` du service oEmbed).
  final String videoId;

  /// Titre affiché dans la barre supérieure (titre du chapitre).
  final String title;

  const YouTubePlayerScreen({
    super.key,
    required this.videoId,
    required this.title,
  });

  @override
  State<YouTubePlayerScreen> createState() => _YouTubePlayerScreenState();
}

class _YouTubePlayerScreenState extends State<YouTubePlayerScreen> {
  /// Contrôleur du lecteur : lance la lecture dès l'ouverture (l'utilisateur
  /// vient de choisir la vidéo) avec les commandes officielles de YouTube,
  /// y compris le bouton plein écran géré par le paquet.
  late final YoutubePlayerController _controller =
      YoutubePlayerController.fromVideoId(
    videoId: widget.videoId,
    autoPlay: true,
    params: const YoutubePlayerParams(
      showControls: true,
      showFullscreenButton: true,
      interfaceLanguage: 'fr',
      strictRelatedVideos: true,
    ),
  );

  @override
  void dispose() {
    // Ferme la WebView sous-jacente : libère le lecteur et arrête la lecture
    // dès la sortie de l'écran.
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        surfaceTintColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: YoutubePlayer(
          controller: _controller,
          aspectRatio: 16 / 9,
          backgroundColor: const Color(0xFF0F172A),
        ),
      ),
    );
  }
}
