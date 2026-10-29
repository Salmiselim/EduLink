import 'package:edulink/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> skipAuth(WidgetTester tester) async {
    await tester.pumpWidget(const EduLinkApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    "L'écran de connexion s'affiche puis « Passer » ouvre l'onglet Cours",
    (WidgetTester tester) async {
      await tester.pumpWidget(const EduLinkApp());
      await tester.pumpAndSettle();

      expect(find.text('EduLink'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.text('Se souvenir de moi'), findsOneWidget);
      expect(find.text('Mot de passe oublié ?'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Apple'), findsOneWidget);

      await tester.tap(find.text('Passer'));
      await tester.pumpAndSettle();
      expect(find.text('EduLink · Cours'), findsOneWidget);
      expect(find.text('Mes cours'), findsOneWidget);
      expect(find.text('Catalogue'), findsOneWidget);
      expect(find.text('Continuer la lecture'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets(
    "L'onglet Cours affiche la vue étudiant « Mes cours »",
    (WidgetTester tester) async {
      await skipAuth(tester);

      expect(find.text('EduLink · Cours'), findsOneWidget);
      expect(find.text('Mes cours'), findsOneWidget);
      expect(find.text('Catalogue'), findsOneWidget);
      expect(find.text('Continuer la lecture'), findsOneWidget);
    },
  );

  testWidgets(
    "La barre inférieure permet d'atteindre la Marketplace",
    (WidgetTester tester) async {
      await skipAuth(tester);

      await tester.tap(find.text('Marketplace'));
      await tester.pumpAndSettle();

      expect(find.text('EduLink · Marketplace'), findsOneWidget);
      expect(find.text('Explorer'), findsOneWidget);
    },
  );
}
