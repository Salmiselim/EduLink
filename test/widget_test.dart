import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:edulink/main.dart';
import 'package:edulink/providers/forum_provider.dart';

void main() {
  testWidgets('EduLink Forum renders successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ForumProvider()),
        ],
        child: const EduLinkApp(),
      ),
    );

    // Verify forum header exists
    expect(find.text("Forum d'entraide"), findsOneWidget);
  });
}
