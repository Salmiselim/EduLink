import 'package:edulink/features/courses/screens/chapter_reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lecture vidéo intégrée du module Cours : la fiche vidéo du lecteur de
/// chapitres propose la lecture dans l'application ; sur une plateforme sans
/// WebView (comme l'environnement de test sur poste), elle retombe
/// proprement sur l'ouverture externe dans YouTube.
void main() {
  testWidgets(
    'Le lecteur affiche la fiche vidéo YouTube et son action de lecture',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: ChapterReaderScreen(
            courseId: 'course_ia_3',
            chapterId: 'ia_c3',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Réseaux de neurones : architecture'), findsOneWidget);
      expect(find.text('Vidéo YouTube'), findsOneWidget);
      expect(find.textContaining('oEmbed'), findsOneWidget);
      // Sur le poste de test (sans WebView) : repli externe explicite.
      expect(find.text('Ouvrir dans YouTube'), findsOneWidget);
    },
  );
}
