import 'package:flutter/material.dart';
import '../screens/ask_question_screen.dart';
import '../screens/question_detail_screen.dart';
import '../screens/teacher_inbox_screen.dart';

/// Routes nommées du module Forum (M3).
/// La route '/' est gérée par `home` dans MaterialApp.
class AppRoutes {
  AppRoutes._();

  static const String forumAsk = '/forum/ask';
  static const String forumQuestion = '/forum/question'; // arguments : String postId
  static const String forumInbox = '/forum/inbox';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case forumAsk:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AskQuestionScreen(),
        );
      case forumQuestion:
        final args = settings.arguments;
        if (args is! String) return onUnknownRoute(settings);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => QuestionDetailScreen(postId: args),
        );
      case forumInbox:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const TeacherInboxScreen(),
        );
      default:
        return onUnknownRoute(settings);
    }
  }

  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Page introuvable')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  "Cette page n'existe pas (${settings.name ?? 'inconnue'}).",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Retour'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
