import 'package:flutter/material.dart';
import '../models/evaluations_models.dart';
import '../screens/assignment_submit_screen.dart';
import '../screens/assignment_wizard_screen.dart';
import '../screens/document_detail_screen.dart';
import '../screens/document_wizard_screen.dart';
import '../screens/quiz_results_screen.dart';
import '../screens/quiz_take_screen.dart';
import '../screens/quiz_wizard_screen.dart';
import '../screens/submission_grade_screen.dart';

/// Arguments typés transmis à [QuizWizardScreen] (`existing` nul en création, renseigné en édition).
class QuizWizardArgs {
  final Quiz? existing;
  const QuizWizardArgs({this.existing});
}

/// Arguments typés identifiant le quiz à démarrer dans [QuizTakeScreen].
class QuizTakeArgs {
  final String quizId;
  const QuizTakeArgs({required this.quizId});
}

/// Arguments typés pour [QuizResultsScreen], portant l'identifiant du quiz
/// et optionnellement celui d'une tentative étudiante précise.
class QuizResultsArgs {
  final String quizId;
  final String? attemptId;
  const QuizResultsArgs({required this.quizId, this.attemptId});
}

/// Arguments typés transmis à [AssignmentWizardScreen] pour créer ou modifier un devoir.
class AssignmentWizardArgs {
  final Assignment? existing;
  const AssignmentWizardArgs({this.existing});
}

/// Arguments typés ciblant le devoir concerné par un dépôt dans [AssignmentSubmitScreen].
class AssignmentSubmitArgs {
  final String assignmentId;
  const AssignmentSubmitArgs({required this.assignmentId});
}

/// Arguments typés identifiant la copie étudiante à noter dans [SubmissionGradeScreen].
class SubmissionGradeArgs {
  final String submissionId;
  const SubmissionGradeArgs({required this.submissionId});
}

/// Arguments typés ciblant le document de cours affiché dans [DocumentDetailScreen].
class DocumentDetailArgs {
  final String documentId;
  const DocumentDetailArgs({required this.documentId});
}

/// Arguments typés transmis à [DocumentWizardScreen] pour l'ajout ou l'édition d'un document.
class DocumentWizardArgs {
  final CourseDocument? existing;
  const DocumentWizardArgs({this.existing});
}

/// Table de routage nommé dédiée aux écrans du module Évaluations.
/// Associe chaque constante de chemin à son constructeur de page via [onGenerateRoute]
/// en castant `settings.arguments` vers l'objet d'arguments typé correspondant.
class EvaluationsRoutes {
  EvaluationsRoutes._();

  /// Route racine de l'application principale.
  static const String home = '/';

  /// Chemin vers l'assistant enseignant de création/modification de quiz.
  static const String quizWizard = '/evaluations/quiz-wizard';

  /// Chemin vers l'écran étudiant de passage chronométré d'un quiz.
  static const String quizTake = '/evaluations/quiz-take';

  /// Chemin vers l'écran des résultats, corrections et statistiques d'un quiz.
  static const String quizResults = '/evaluations/quiz-results';

  /// Chemin vers l'assistant enseignant de création/modification d'un devoir.
  static const String assignmentWizard = '/evaluations/assignment-wizard';

  /// Chemin vers l'écran étudiant de remise de devoir.
  static const String assignmentSubmit = '/evaluations/assignment-submit';

  /// Chemin vers l'écran enseignant de notation d'une copie déposée.
  static const String submissionGrade = '/evaluations/submission-grade';

  /// Chemin vers la fiche détaillée et le téléchargement d'un document de cours.
  static const String documentDetail = '/evaluations/document-detail';

  /// Chemin vers le formulaire enseignant d'ajout/modification d'un document.
  static const String documentWizard = '/evaluations/document-wizard';

  /// Génère la [MaterialPageRoute] correspondant à [settings.name] en extrayant
  /// ses arguments typés. Renvoie `null` si la route n'appartient pas à ce module.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case quizWizard:
        // Récupère éventuellement le quiz existant pour préremplir le formulaire en édition.
        final args = settings.arguments as QuizWizardArgs?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => QuizWizardScreen(existing: args?.existing),
        );
      case quizTake:
        // Extrait l'identifiant obligatoire du quiz pour lancer une nouvelle tentative.
        final args = settings.arguments as QuizTakeArgs;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => QuizTakeScreen(quizId: args.quizId),
        );
      case quizResults:
        // Transmet le quiz et, côté étudiant, la tentative ciblée pour afficher le corrigé.
        final args = settings.arguments as QuizResultsArgs;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => QuizResultsScreen(
            quizId: args.quizId,
            attemptId: args.attemptId,
          ),
        );
      case assignmentWizard:
        // Permet d'ouvrir le wizard de devoir en mode création (`null`) ou modification.
        final args = settings.arguments as AssignmentWizardArgs?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => AssignmentWizardScreen(existing: args?.existing),
        );
      case assignmentSubmit:
        // Ouvre le formulaire de dépôt rattaché à l'identifiant du devoir.
        final args = settings.arguments as AssignmentSubmitArgs;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => AssignmentSubmitScreen(
            assignmentId: args.assignmentId,
          ),
        );
      case submissionGrade:
        // Charge la copie étudiante sélectionnée pour saisie de la note et du commentaire.
        final args = settings.arguments as SubmissionGradeArgs;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => SubmissionGradeScreen(
            submissionId: args.submissionId,
          ),
        );
      case documentDetail:
        // Affiche les métadonnées et l'action de téléchargement du support sélectionné.
        final args = settings.arguments as DocumentDetailArgs;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => DocumentDetailScreen(documentId: args.documentId),
        );
      case documentWizard:
        // Ouvre l'éditeur de document pédagogique en création ou en mise à jour.
        final args = settings.arguments as DocumentWizardArgs?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => DocumentWizardScreen(existing: args?.existing),
        );
      default:
        return null;
    }
  }
}
