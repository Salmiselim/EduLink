import 'package:flutter_test/flutter_test.dart';
import 'package:edulink/main.dart';

void main() {
  testWidgets('Marketplace screen renders main views', (WidgetTester tester) async {
    await tester.pumpWidget(const EduLinkMarketplaceApp());

    expect(find.text('EduLink · Marketplace'), findsOneWidget);
    expect(find.text('Explorer'), findsOneWidget);
    expect(find.text('Mes commandes'), findsOneWidget);
  });
}
