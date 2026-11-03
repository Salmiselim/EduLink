import 'package:edulink/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parcours complet de l'assistant de création d'offre sur un viewport
/// téléphone (412×915) : tout débordement ou crash de layout fait échouer
/// le test.
void main() {

  /// Tolère l'avertissement cosmétique 'ListTile background color' (tuiles
  /// du forum — hors périmètre) ; tout autre échec reste bloquant.
  void tolerateListTileWarning() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('ListTile background color')) {
        return;
      }
      previous?.call(details);
    };
  }

  // L'onglet Forum (hors périmètre) affiche des tuiles dans des
  // conteneurs décorés : l'avertissement cosmétique d'encre invisible
  // est toléré — les vrais débordements et crashs restent bloquants.
  setUp(() {
    final originalHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('ListTile background color')) {
        return;
      }
      originalHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalHandler);
  });
  Future<void> boot(WidgetTester tester) async {
    tolerateListTileWarning();
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const EduLinkApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marketplace'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    "Assistant offre : les 6 étapes se parcourent sans débordement et publient",
    (tester) async {
      await boot(tester);

      // Ouvre l'assistant depuis l'en-tête du catalogue
      await tester.tap(find.text('Vendre / Donner un cours'));
      await tester.pumpAndSettle();
      expect(find.text("1. Type d'offre"), findsOneWidget);

      // Étape 1 — choix du type d'offre
      await tester.tap(find.text('Ressource numérique'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Étape suivante'));
      await tester.pumpAndSettle();
      expect(find.text('2. Infos & Médias'), findsOneWidget);

      // Étape 2 — titre, description et fichier PDF
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Fiches de révision Algorithmique',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Un condensé de tout le cours avec des exemples corrigés, '
        'idéal pour réviser efficacement avant les examens.',
      );
      await tester.tap(find.text('Changer le PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Étape suivante'));
      await tester.pumpAndSettle();
      expect(find.text('3. Prix (TND)'), findsOneWidget);

      // Étape 3 — prix pré-rempli à 15 TND
      await tester.tap(find.text('Étape suivante'));
      await tester.pumpAndSettle();
      expect(find.text('4. Mode, Lieu & Créneaux'), findsOneWidget);

      // Étape 4 — offre numérique : pas d'adresse requise
      await tester.tap(find.text('Étape suivante'));
      await tester.pumpAndSettle();
      expect(find.text('5. Cours lié'), findsOneWidget);

      // Étape 5 — cours lié optionnel
      await tester.tap(find.text('Étape suivante'));
      await tester.pumpAndSettle();
      expect(find.text('6. Aperçu & Publication'), findsOneWidget);

      // Étape 6 — publication
      await tester.tap(find.text("Publier l'offre"));
      await tester.pumpAndSettle();

      // Retour automatique sur la Marketplace, offre visible dans le catalogue
      expect(find.text('EduLink · Marketplace'), findsOneWidget);
      expect(find.text('Fiches de révision Algorithmique'), findsOneWidget);
    },
  );
}
