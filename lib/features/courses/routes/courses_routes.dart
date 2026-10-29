import 'package:flutter/material.dart';
import '../models/courses_models.dart';
import '../screens/course_detail_screen.dart';
import '../screens/course_manage_screen.dart';
import '../screens/course_wizard_screen.dart';
import '../screens/chapter_reader_screen.dart';

// ============================================================================
// GESTION CENTRALISÉE DES ROUTES — MODULE M2 : COURS
// Même pattern que `MarketplaceRoutes` (M5) et `EvaluationsRoutes` (M4) :
// routes nommées, arguments typés, retour null si la route ne nous appartient
// pas (le répartiteur `EduLinkRoutes` de main.dart chaîne tous les modules).
// ============================================================================

/// Arguments typés pour la page d'un cours (`CourseDetailScreen`)
class CourseDetailArgs {
  final String courseId;
  const CourseDetailArgs({required this.courseId});
}

/// Arguments typés pour le lecteur de chapitres (`ChapterReaderScreen`)
class ChapterReaderArgs {
  final String courseId;
  final String chapterId;
  const ChapterReaderArgs({required this.courseId, required this.chapterId});
}

/// Arguments typés pour l'assistant de création / modification de cours
/// (`CourseWizardScreen`)
class CourseWizardArgs {
  final Course? existingCourse;
  const CourseWizardArgs({this.existingCourse});
}

/// Arguments typés pour le tableau de bord d'un cours (`CourseManageScreen`)
class CourseManageArgs {
  final String courseId;
  const CourseManageArgs({required this.courseId});
}

/// Table centralisée des routes nommées du module Cours (M2)
class CoursesRoutes {
  CoursesRoutes._();

  static const String courseDetail = '/courses/course-detail';
  static const String chapterReader = '/courses/chapter-reader';
  static const String courseWizard = '/courses/course-wizard';
  static const String courseManage = '/courses/course-manage';

  /// Générateur de routes centralisé branché sur `MaterialApp.onGenerateRoute`
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case courseDetail:
        final args = settings.arguments as CourseDetailArgs;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => CourseDetailScreen(courseId: args.courseId),
        );
      case chapterReader:
        final args = settings.arguments as ChapterReaderArgs;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ChapterReaderScreen(
            courseId: args.courseId,
            chapterId: args.chapterId,
          ),
        );
      case courseWizard:
        final args = settings.arguments as CourseWizardArgs?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => CourseWizardScreen(existingCourse: args?.existingCourse),
        );
      case courseManage:
        final args = settings.arguments as CourseManageArgs;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => CourseManageScreen(courseId: args.courseId),
        );
      default:
        return null;
    }
  }
}
