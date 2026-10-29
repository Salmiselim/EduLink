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

class QuizWizardArgs {
  final Quiz? existing;
  const QuizWizardArgs({this.existing});
}

class QuizTakeArgs {
  final String quizId;
  const QuizTakeArgs({required this.quizId});
}

class QuizResultsArgs {
  final String quizId;
  final String? attemptId;
  const QuizResultsArgs({required this.quizId, this.attemptId});
}

class AssignmentWizardArgs {
  final Assignment? existing;
  const AssignmentWizardArgs({this.existing});
}

class AssignmentSubmitArgs {
  final String assignmentId;
  const AssignmentSubmitArgs({required this.assignmentId});
}

class SubmissionGradeArgs {
  final String submissionId;
  const SubmissionGradeArgs({required this.submissionId});
}

class DocumentDetailArgs {
  final String documentId;
  const DocumentDetailArgs({required this.documentId});
}

class DocumentWizardArgs {
  final CourseDocument? existing;
  const DocumentWizardArgs({this.existing});
}

class EvaluationsRoutes {
  EvaluationsRoutes._();

  static const String home = '/';
  static const String quizWizard = '/evaluations/quiz-wizard';
  static const String quizTake = '/evaluations/quiz-take';
  static const String quizResults = '/evaluations/quiz-results';
  static const String assignmentWizard = '/evaluations/assignment-wizard';
  static const String assignmentSubmit = '/evaluations/assignment-submit';
  static const String submissionGrade = '/evaluations/submission-grade';
  static const String documentDetail = '/evaluations/document-detail';
  static const String documentWizard = '/evaluations/document-wizard';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case quizWizard:
        final args = settings.arguments as QuizWizardArgs?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => QuizWizardScreen(existing: args?.existing),
        );
      case quizTake:
        final args = settings.arguments as QuizTakeArgs;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => QuizTakeScreen(quizId: args.quizId),
        );
      case quizResults:
        final args = settings.arguments as QuizResultsArgs;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => QuizResultsScreen(
            quizId: args.quizId,
            attemptId: args.attemptId,
          ),
        );
      case assignmentWizard:
        final args = settings.arguments as AssignmentWizardArgs?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => AssignmentWizardScreen(existing: args?.existing),
        );
      case assignmentSubmit:
        final args = settings.arguments as AssignmentSubmitArgs;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => AssignmentSubmitScreen(
            assignmentId: args.assignmentId,
          ),
        );
      case submissionGrade:
        final args = settings.arguments as SubmissionGradeArgs;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => SubmissionGradeScreen(
            submissionId: args.submissionId,
          ),
        );
      case documentDetail:
        final args = settings.arguments as DocumentDetailArgs;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => DocumentDetailScreen(documentId: args.documentId),
        );
      case documentWizard:
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
