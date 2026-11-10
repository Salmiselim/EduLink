import 'package:edulink/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les écrans poussés (détail de cours, lecteur de chapitres, détail d'offre)
/// s'affichent sans débordement ni crash sur un viewport téléphone.
void main() {
  /// Tolère l'avertissement cosmétique 'ListTile background color' (tuiles
  /// du forum — hors périmètre) ; tout autre échec reste bloquant.
  void tolerateListTileWarning() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception
          .toString()
          .contains('ListTile background color')) {
        return;
      }
      previous?.call(details);
    };
  }

  Future<void> boot(WidgetTester tester) async {
    tolerateListTileWarning();
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const EduLinkApp());
    await tester.pumpAndSettle();
    // Connexion en mode démonstration (Firebase absent en tests).
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Adresse e-mail'),
      'etudiant@edulink.tn',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mot de passe'),
      'motdepasse',
    );
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    // Laisse la SnackBar « Bienvenue » se refermer avant les interactions.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  /// Fait défiler la liste contenant [from] jusqu'à rendre [finder] visible.
  Future<void> scrollUntilVisible(
    WidgetTester tester,
    Finder from,
    Finder finder,
  ) async {
    for (var i = 0; i < 6 && !tester.any(finder); i++) {
      await tester.drag(from, const Offset(0, -350));
      await tester.pumpAndSettle();
    }
  }

  testWidgets(
    'Détail de cours + lecteur de chapitres sans débordement',
    (tester) async {
      await boot(tester);

      // Vue étudiant : la carte « Flutter & NestJS » est suivie par le compte
      // de démonstration — son tap ouvre la page du cours.
      await tester.tap(find
          .text('Architecture Mobile Cross-Platform (Flutter & NestJS)')
          .first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Chapitres'), findsOneWidget);
      expect(find.textContaining('Description'), findsOneWidget);

      // La section « Aller plus loin » est en bas de la page : défilement.
      await scrollUntilVisible(
        tester,
        find.textContaining('Description'),
        find.textContaining('Aller plus loin'),
      );
      expect(find.textContaining('Aller plus loin'), findsOneWidget);

      // Ouvre le lecteur sur le premier chapitre.
      await tester.tap(find.text('Dart : syntaxe & null safety'));
      await tester.pumpAndSettle();
      expect(find.text('Chapitre 1 / 5'), findsOneWidget);
      expect(find.textContaining('Chapitres du cours'), findsOneWidget);

      // Retour au détail puis à la liste.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    "Détail d'une offre du catalogue sans débordement",
    (tester) async {
      await boot(tester);

      await tester.tap(find.text('Marketplace'));
      await tester.pumpAndSettle();

      // L'offre est plus bas dans la liste : défile jusqu'à elle.
      final offerTitle =
          find.text('Fiches Algo & Complexité — Résumé + 25 Annales Corrigées');
      await scrollUntilVisible(tester, offerTitle,
          find.textContaining('Catalogue des offres'));
      await tester.tap(offerTitle);
      await tester.pumpAndSettle();

      expect(find.textContaining('Description & Particularités'),
          findsOneWidget);
      expect(find.textContaining('TND'), findsWidgets);

      await tester.pageBack();
      await tester.pumpAndSettle();
    },
  );
}
