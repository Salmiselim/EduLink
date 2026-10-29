import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:edulink/main.dart';
import 'package:edulink/providers/forum_provider.dart';

Widget _buildApp() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ForumProvider()),
    ],
    child: const EduLinkApp(),
  );
}

void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('EduLink Forum renders successfully', (tester) async {
    _useTallScreen(tester);
    await tester.pumpWidget(_buildApp());

    expect(find.text("Forum d'entraide"), findsOneWidget);
  });

  testWidgets('Ask form shows validation errors when empty', (tester) async {
    _useTallScreen(tester);
    await tester.pumpWidget(_buildApp());

    await tester.tap(find.text('Poser une question'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Publier ma question'));
    await tester.pumpAndSettle();

    expect(find.text('Veuillez saisir un titre'), findsOneWidget);
    expect(find.text('Veuillez décrire votre question'), findsOneWidget);
  });

  testWidgets('Valid question is published and its detail opens',
      (tester) async {
    _useTallScreen(tester);
    await tester.pumpWidget(_buildApp());

    await tester.tap(find.text('Poser une question'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Comment utiliser Provider ?');
    await tester.enterText(
        fields.at(1), 'Je voudrais comprendre la différence entre read et watch.');
    await tester.tap(find.text('Publier ma question'));
    await tester.pumpAndSettle();

    expect(find.text('Détail de la question'), findsOneWidget);
    expect(find.text('Comment utiliser Provider ?'), findsOneWidget);
  });

  testWidgets('Empty reply shows an error message', (tester) async {
    _useTallScreen(tester);
    await tester.pumpWidget(_buildApp());

    await tester.tap(find.text('Rappel : Début des séances de révision la semaine prochaine'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text("Écrivez votre réponse avant de l'envoyer"), findsOneWidget);
  });
}
