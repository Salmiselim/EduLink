import 'package:edulink/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Ouvre l'application et saute l'écran de connexion (mode démonstration)
  Future<void> skipAuth(WidgetTester tester) async {
    await tester.pumpWidget(const EduLinkApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    "L'écran de connexion s'affiche puis « Passer » ouvre l'application",
    (WidgetTester tester) async {
      await tester.pumpWidget(const EduLinkApp());
      await tester.pumpAndSettle();

      // Écran de connexion (interface de démonstration)
      expect(find.text('EduLink'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.text('Se souvenir de moi'), findsOneWidget);
      expect(find.text('Mot de passe oublié ?'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Apple'), findsOneWidget);

      // « Passer » ouvre directement le shell intégré (onglet Marketplace)
      await tester.tap(find.text('Passer'));
      await tester.pumpAndSettle();
      expect(find.text('EduLink · Marketplace'), findsOneWidget);
      expect(find.text('Explorer'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets(
    "L'onglet Cours affiche la vue étudiant « Mes cours »",
    (WidgetTester tester) async {
      await skipAuth(tester);

      // Bascule vers l'onglet Cours via la barre inférieure
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
