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
    "L'écran de connexion s'affiche puis « Passer » ouvre l'onglet Cours",
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

      // « Passer » ouvre le shell intégré : l'onglet de démarrage est Cours
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
    "La barre inférieure permet d'atteindre la Marketplace",
    (WidgetTester tester) async {
      await skipAuth(tester);

      // Depuis l'onglet Cours (démarrage), bascule vers Marketplace
      await tester.tap(find.text('Marketplace'));
      await tester.pumpAndSettle();

      expect(find.text('EduLink · Marketplace'), findsOneWidget);
      expect(find.text('Explorer'), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------- Forum (M3)
  group('Forum', () {
    Future<void> openForum(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await skipAuth(tester);
      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Forum'),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets("L'onglet Forum affiche le fil de questions", (tester) async {
      await openForum(tester);

      expect(find.text("Forum d'entraide"), findsOneWidget);
      expect(find.text('Poser une question'), findsOneWidget);
    });

    testWidgets('Le formulaire refuse une question vide', (tester) async {
      await openForum(tester);

      await tester.tap(find.text('Poser une question'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publier ma question'));
      await tester.pumpAndSettle();

      expect(find.text('Veuillez saisir un titre'), findsOneWidget);
      expect(find.text('Veuillez décrire votre question'), findsOneWidget);
    });

    testWidgets('Une question valide est publiée et son détail s\'ouvre',
        (tester) async {
      await openForum(tester);

      await tester.tap(find.text('Poser une question'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Comment utiliser Provider ?');
      await tester.enterText(fields.at(1),
          'Je voudrais comprendre la différence entre read et watch.');
      await tester.tap(find.text('Publier ma question'));
      await tester.pumpAndSettle();

      expect(find.text('Détail de la question'), findsOneWidget);
      expect(find.text('Comment utiliser Provider ?'), findsOneWidget);
    });

    testWidgets('Une réponse vide affiche un message d\'erreur',
        (tester) async {
      await openForum(tester);

      await tester.tap(find.text(
          'Rappel : Début des séances de révision la semaine prochaine'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text("Écrivez votre réponse avant de l'envoyer"),
          findsOneWidget);
    });
  });
}
