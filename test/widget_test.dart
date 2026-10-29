import 'package:edulink/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Le shell EduLink intégré (M4 + M5) affiche Marketplace et la barre à 5 onglets',
    (WidgetTester tester) async {
      await tester.pumpWidget(const EduLinkApp());

      // Onglet de démarrage : Marketplace (M5)
      expect(find.text('EduLink · Marketplace'), findsOneWidget);
      expect(find.text('Explorer'), findsOneWidget);

      // Barre de navigation inférieure commune aux 5 modules
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Cours'), findsOneWidget);
      expect(find.text('Évaluations'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
    },
  );

  testWidgets(
    "L'onglet Cours (M2) affiche la vue étudiant « Mes cours »",
    (WidgetTester tester) async {
      await tester.pumpWidget(const EduLinkApp());
      await tester.pumpAndSettle();

      // Bascule vers l'onglet Cours (M2) via la barre inférieure
      await tester.tap(find.text('Cours'));
      await tester.pumpAndSettle();

      // AppBar du module + bascule des vues (SegmentedButton)
      expect(find.text('EduLink · Cours'), findsOneWidget);
      expect(find.text('Mes cours'), findsOneWidget);
      expect(find.text('Catalogue'), findsOneWidget);

      // L'étudiant simulé suit déjà des cours dans le mock : la section
      // « reprise de lecture » et les cartes de progression s'affichent.
      expect(find.text('Continuer la lecture'), findsOneWidget);
    },
  );
}
