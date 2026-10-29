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
}
