import 'package:flutter/material.dart';
import '../screens/ask_question_screen.dart';
import '../screens/question_detail_screen.dart';
import '../screens/teacher_inbox_screen.dart';
import '../widgets/forum_ui.dart';

/// Arguments de la route [ForumRoutes.forumAsk].
/// - [postId] : modifier une question existante ;
/// - [courseName] : préremplir le cours d'une nouvelle question (ex. depuis la
///   fiche d'un cours du module Cours).
class ForumAskArgs {
  final String? postId;
  final String? courseName;

  const ForumAskArgs({this.postId, this.courseName});
}

/// Déclaration et résolution des routes nommées propres au Forum.
/// S'intègre dans le répartiteur central `EduLinkRoutes` (`main.dart`) en
/// retournant `null` lorsque le chemin demandé appartient à une autre fonctionnalité.
class ForumRoutes {
  ForumRoutes._();

  /// Route vers le formulaire de publication d'une nouvelle question.
  static const String forumAsk = '/forum/ask'; // argument optionnel : ForumAskArgs (ou String postId)

  /// Route vers le détail d'une question (attend l'identifiant `String postId` en `arguments`).
  static const String forumQuestion = '/forum/question';

  /// Route vers la boîte de réception des questions en attente côté enseignant.
  static const String forumInbox = '/forum/inbox';

  /// Génère la `MaterialPageRoute` correspondant à [settings.name] et vérifie
  /// le typage des arguments transmis via `Navigator.pushNamed`.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case forumAsk:
        // Argument optionnel : question à modifier et/ou cours à préremplir.
        final args = settings.arguments;
        final editId = args is ForumAskArgs
            ? args.postId
            : (args is String ? args : null);
        final course = args is ForumAskArgs ? args.courseName : null;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => AskQuestionScreen(postId: editId, initialCourse: course),
        );
      case forumQuestion:
        // Vérification défensive de l'identifiant de question reçu en argument.
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

  /// Écran de secours affiché lorsqu'une route du Forum reçoit un argument absent ou mal typé.
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
            // Permet de dépiler la route invalide pour revenir à l'écran précédent.
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
