import 'package:flutter/material.dart';
import '../screens/ask_question_screen.dart';
import '../screens/question_detail_screen.dart';
import '../screens/teacher_inbox_screen.dart';
import '../widgets/forum_ui.dart';

/// Routes nommées du module Forum (M3).
/// Même pattern que `CoursesRoutes`, `MarketplaceRoutes` et `EvaluationsRoutes` :
/// retourne null si la route ne nous appartient pas (le répartiteur
/// `EduLinkRoutes` de main.dart chaîne tous les modules).
class ForumRoutes {
  ForumRoutes._();

  static const String forumAsk = '/forum/ask';
  static const String forumQuestion = '/forum/question'; // arguments : String postId
  static const String forumInbox = '/forum/inbox';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case forumAsk:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AskQuestionScreen(),
        );
      case forumQuestion:
        final args = settings.arguments;
        if (args is! String) return invalidRoute(settings);
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
        return null;
    }
  }

  /// Page affichée quand une route du Forum reçoit de mauvais arguments.
  static Route<dynamic> invalidRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => Scaffold(
        backgroundColor: ForumColors.scaffold,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          title: const ForumPageTitle('Page introuvable'),
        ),
        body: Center(
          child: ForumEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Page introuvable',
            subtitle: "Cette page n'existe pas (${settings.name ?? 'inconnue'}).",
            action: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: ForumColors.primary,
              ),
              child: const Text(
                'Retour',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
