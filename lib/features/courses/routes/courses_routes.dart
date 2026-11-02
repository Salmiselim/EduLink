import 'package:flutter/material.dart';
import '../models/courses_models.dart';
import '../screens/course_detail_screen.dart';
import '../screens/course_manage_screen.dart';
import '../screens/course_wizard_screen.dart';
import '../screens/chapter_reader_screen.dart';

// Déclaration des routes nommées et des classes d'arguments typés du module Cours.
// S'intègre au routeur global de l'application (`main.dart`) en retournant `null`
// lorsque le chemin demandé relève d'un autre module.

/// Arguments typés transmis lors de l'ouverture de [CourseDetailScreen].
/// Contient l'identifiant du cours à charger depuis `CoursesController`.
class CourseDetailArgs {
  final String courseId;
  const CourseDetailArgs({required this.courseId});
}

/// Arguments typés transmis lors de l'ouverture de [ChapterReaderScreen].
/// Précise le cours concerné ainsi que le chapitre initial à afficher dans le lecteur.
class ChapterReaderArgs {
  final String courseId;
  final String chapterId;
  const ChapterReaderArgs({required this.courseId, required this.chapterId});
}

/// Arguments typés facultatifs transmis à [CourseWizardScreen].
/// Si [existingCourse] est fourni, l'assistant s'ouvre en mode édition pré-rempli ;
/// s'il vaut `null`, un nouveau cours en brouillon est initialisé.
class CourseWizardArgs {
  final Course? existingCourse;
  const CourseWizardArgs({this.existingCourse});
}

/// Arguments typés transmis à [CourseManageScreen] pour gérer les chapitres
/// et consulter la progression des étudiants inscrits à [courseId].
class CourseManageArgs {
  final String courseId;
  const CourseManageArgs({required this.courseId});
}

/// Registre statique des chemins de navigation et fabrique de routes du module Cours.
class CoursesRoutes {
  CoursesRoutes._();

  /// Route vers la fiche détaillée d'un cours (présentation, chapitres et inscription).
  static const String courseDetail = '/courses/course-detail';

  /// Route plein écran vers le lecteur interactif de chapitres.
  static const String chapterReader = '/courses/chapter-reader';

  /// Route vers l'assistant en quatre étapes de création ou d'édition de cours.
  static const String courseWizard = '/courses/course-wizard';

  /// Route vers l'écran enseignant de gestion des chapitres et de suivi des inscrits.
  static const String courseManage = '/courses/course-manage';

  /// Résout une route nommée à partir de [settings] et extrait ses arguments typés
  /// pour instancier l'écran correspondant dans une [MaterialPageRoute].
  /// Retourne `null` si `settings.name` n'appartient pas au périmètre `/courses/*`,
  /// ce qui permet au répartiteur principal de déléguer la résolution aux autres modules.
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
