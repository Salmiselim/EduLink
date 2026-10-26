import 'package:flutter_test/flutter_test.dart';
import 'package:edulink/main.dart';

void main() {
  testWidgets('L\'onglet Évaluations s\'affiche', (WidgetTester tester) async {
    await tester.pumpWidget(const EduLinkEvaluationsApp());
    expect(find.text('EduLink · Évaluations'), findsOneWidget);
    expect(find.text('À faire'), findsOneWidget);
  });
}
