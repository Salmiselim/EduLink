import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

// Visionneuse PDF intégrée du module Cours : affiche un document importé
// localement par l'enseignant, en plein écran, avec navigation par pages
// native (flutter_pdfview, Android/iOS uniquement — l'accès est gardé par
// l'appelant qui vérifie la plateforme avant de pousser cet écran).

/// Lecteur plein écran d'un document PDF local.
class PdfViewerScreen extends StatelessWidget {
  final File file;
  final String title;

  const PdfViewerScreen({super.key, required this.file, required this.title});

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
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: PDFView(
        filePath: file.path,
        enableSwipe: true,
        swipeHorizontal: true,
        autoSpacing: true,
        pageFling: true,
        pageSnap: true,
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              duration: Duration(seconds: 3),
              content: Text("Impossible d'ouvrir ce document."),
            ),
          );
        },
        onPageError: (page, error) {
          debugPrint('[PdfViewer] Erreur page $page : $error');
        },
      ),
    );
  }
}
