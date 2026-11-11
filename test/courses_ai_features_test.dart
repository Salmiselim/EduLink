import 'dart:io';

import 'package:edulink/features/courses/data/courses_mock_data.dart';
import 'package:edulink/features/courses/models/courses_models.dart';
import 'package:edulink/features/courses/screens/chapter_reader_screen.dart';
import 'package:edulink/features/courses/screens/course_wizard_screen.dart';
import 'package:edulink/features/courses/screens/courses_screen.dart';
import 'package:edulink/features/courses/services/courses_ai_service.dart';
import 'package:edulink/features/courses/services/courses_document_service.dart';
import 'package:edulink/features/courses/widgets/course_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fonctionnalités nouvelles du module Cours : traductions IA enregistrées,
/// notifications des inscrits, repli propre des services IA/Stockage sans
/// configuration, et présence des nouveaux outils dans les écrans.
void main() {
  final CoursesController controller = CoursesController.instance;

  testWidgets(
    "L'assistant de cours affiche les outils IA (description, orthographe)",
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: CourseWizardScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Suggérer la description'), findsOneWidget);
      expect(find.text("Vérifier l'orthographe"), findsOneWidget);
      expect(find.text('Ajouter une image de couverture'), findsOneWidget);
    },
  );

  testWidgets(
    'Le lecteur affiche le sélecteur de langues et les outils IA de lecture',
    (tester) async {
      // Traduction enregistrée au préalable (comme le ferait l'enseignant).
      controller.saveChapterTranslation(
        'course_flutter_4',
        'fl_c1',
        'en',
        'Types, collections and null safety in Dart.',
      );

      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: ChapterReaderScreen(
            courseId: 'course_flutter_4',
            chapterId: 'fl_c1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Anglais'), findsOneWidget);
      expect(find.text('Résumé (IA)'), findsOneWidget);
      expect(find.text('Traduire (IA)'), findsOneWidget);

      // Bascule vers la traduction enregistrée.
      await tester.tap(find.text('Anglais'));
      await tester.pumpAndSettle();
      expect(find.textContaining('null safety in Dart'), findsOneWidget);

      // Retour au contenu original.
      await tester.tap(find.text('Original'));
      await tester.pumpAndSettle();
      expect(find.textContaining('null safety et'), findsOneWidget);
    },
  );

  test(
    'Les traductions enregistrées sont stockées et relues dans le contrôleur',
    () {
      controller.saveChapterTranslation(
        'course_algo_1',
        'algo_c2',
        'es',
        'Listas enlazadas, pilas y colas.',
      );
      final chapter = controller
          .chaptersOf('course_algo_1')
          .firstWhere((c) => c.id == 'algo_c2');
      expect(chapter.translations['es'], 'Listas enlazadas, pilas y colas.');
      expect(chapter.contentIn('es'), 'Listas enlazadas, pilas y colas.');
      // Sans traduction : retour sur le contenu original.
      expect(chapter.contentIn(null), chapter.content);
      expect(chapter.contentIn('ar'), chapter.content);

      controller.saveCourseDescriptionTranslation(
        'course_algo_1',
        'en',
        'Complete algorithms course with corrected exercises.',
      );
      final course = controller.courseById('course_algo_1')!;
      expect(
        course.descriptionTranslations['en'],
        'Complete algorithms course with corrected exercises.',
      );
      expect(
        course.descriptionIn('en'),
        'Complete algorithms course with corrected exercises.',
      );
      expect(course.descriptionIn(null), course.description);
    },
  );

  test(
    "L'ajout d'un chapitre notifie les étudiants inscrits (hors auteur)",
    () {
      final before = controller.notificationsFor('student_sara').length;
      final chapter = controller.addChapter(
        'course_algo_1',
        title: 'Chapitre de test — notifications',
        type: ChapterType.text,
        content: 'Contenu de test.',
        durationMin: 30,
      );

      final saraNotifications = controller.notificationsFor('student_sara');
      expect(saraNotifications.length, before + 1);
      final notification = saraNotifications.first;
      expect(notification.type, 'new_chapter');
      expect(notification.courseId, 'course_algo_1');
      expect(notification.read, isFalse);

      // L'auteur (utilisateur courant) ne se notifie pas lui-même.
      expect(controller.notificationsFor(controller.currentUserId).length, 0);

      // Marquage « lu ».
      controller.markNotificationRead(notification.id);
      expect(
        controller
            .notificationsFor('student_sara')
            .first
            .read,
        isTrue,
      );

      // Nettoyage de l'état partagé du module.
      controller.deleteChapter('course_algo_1', chapter.id);
    },
  );

  test(
    "Le service IA sans clé lève une exception explicite (repli gracieux)",
    () async {
      // En tests, aucune clé n'est fournie via --dart-define.
      expect(CoursesAiService.instance.isConfigured, isFalse);
      await expectLater(
        CoursesAiService.instance.suggestDescription(
          title: 'Test',
          subject: 'Algorithmique',
          level: 'L1',
        ),
        throwsA(isA<AiUnavailableException>()),
      );
    },
  );

  test(
    "Le service de documents refuse proprement un fichier introuvable (null)",
    () async {
      // Garde : fichier absent → retour immédiat, aucune copie tentée.
      final reference =
          await CoursesDocumentService.instance.importChapterPdf(
        courseId: 'course_algo_1',
        file: File('fichier-inexistant.pdf'),
      );
      expect(reference, isNull);
    },
  );

  test(
    "Les références locales sont reconnues et résolues en null si absentes",
    () async {
      expect(
        CoursesDocumentService.isLocalReference(
          'edulink_files/courses/course_x/doc.pdf',
        ),
        isTrue,
      );
      expect(
        CoursesDocumentService.isLocalReference('https://exemple.com/doc.pdf'),
        isFalse,
      );
      expect(
        CoursesDocumentService.isLocalReference(
          '/documents/edulink/chapters/hachage.pdf',
        ),
        isFalse,
      );
      // Fichier inexistant sur cet appareil → résolution null (pas d'erreur).
      final file = await CoursesDocumentService.instance.resolveLocalFile(
        'edulink_files/courses/course_x/inexistant.pdf',
      );
      expect(file, isNull);
    },
  );

  testWidgets(
    "La carte de cours ne déborde pas à largeur réduite ni dans les listes",
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Cours aux valeurs extrêmes : titre long, compteurs élevés.
      controller.toggleCurrentUserRole(); // passe en enseignant (démonstration)
      final course = controller.createCourse(
        title:
            'Cours de vérification avec un titre volontairement très long '
            'pour tester les débordements',
        subject: 'Algorithmique',
        level: 'L1',
        description: 'Description de test.',
      );
      course
        ..chaptersCount = 1234
        ..enrollmentsCount = 5678;

      // Scénario carrousel « Recommandés » : carte de 300 px avec le bouton
      // « S'inscrire » — la ligne de métadonnées doit passer à la ligne.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 300,
                child: CourseCard(course: course, onEnroll: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('1234 chap.'), findsOneWidget);
      expect(find.text('5678 inscrits'), findsOneWidget);

      // Variante enseignant étroite : badge de statut + menu ⋮.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 340,
                child: CourseCard(
                  course: course,
                  isTeacherVariant: true,
                  onTap: () {},
                  onMore: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('5678 inscrits'), findsOneWidget);

      // Liste complète « Mes cours » de l'enseignant à viewport téléphone.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CoursesScreen())),
      );
      await tester.pump();
      expect(find.textContaining('Cours de vérification'), findsOneWidget);

      // Nettoyage de l'état partagé du module.
      controller.deleteCourse(course.id);
      controller.toggleCurrentUserRole(); // retour étudiant
    },
  );
}
