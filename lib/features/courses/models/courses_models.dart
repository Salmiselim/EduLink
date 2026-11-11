import 'package:flutter/material.dart';

// Modèles de données du module Cours.
// Représentent les documents des collections Firestore `courses`,
// `courses/{id}/chapters` et `enrollments`, ainsi que les agrégats de suivi.

/// Format du support pédagogique associé à un chapitre (`text`, `pdf`, `video`, `link`).
/// Détermine le mode de rendu dans `ChapterReaderScreen` et le type de champ
/// affiché dans `ChapterEditSheet`.
enum ChapterType { text, pdf, video, link }

/// Propriétés d'affichage et de sérialisation rattachées à [ChapterType].
extension ChapterTypeX on ChapterType {
  /// Libellé lisible affiché sur les badges et puces de sélection.
  String get label {
    switch (this) {
      case ChapterType.text:
        return 'Texte';
      case ChapterType.pdf:
        return 'PDF';
      case ChapterType.video:
        return 'Vidéo';
      case ChapterType.link:
        return 'Lien';
    }
  }

  /// Identifiant brut enregistré dans le champ `type` du document Firestore.
  String get firestoreValue {
    switch (this) {
      case ChapterType.text:
        return 'text';
      case ChapterType.pdf:
        return 'pdf';
      case ChapterType.video:
        return 'video';
      case ChapterType.link:
        return 'link';
    }
  }

  /// Icône Material associée au format du support dans les listes et en-têtes.
  IconData get icon {
    switch (this) {
      case ChapterType.text:
        return Icons.notes_rounded;
      case ChapterType.pdf:
        return Icons.picture_as_pdf_rounded;
      case ChapterType.video:
        return Icons.play_circle_rounded;
      case ChapterType.link:
        return Icons.link_rounded;
    }
  }

  /// Couleur principale associée au type de support pour les icônes et textes de badge.
  Color get color {
    switch (this) {
      case ChapterType.text:
        return const Color(0xFF2563EB);
      case ChapterType.pdf:
        return const Color(0xFFDC2626);
      case ChapterType.video:
        return const Color(0xFF7C3AED);
      case ChapterType.link:
        return const Color(0xFF16A34A);
    }
  }

  /// Teinte d'arrière-plan atténuée (opacité 10 %) utilisée par `ChapterTypeBadge`.
  Color get background => color.withValues(alpha: 0.1);

  /// Convertit une chaîne issue de Firestore vers la valeur correspondante de [ChapterType].
  /// Retourne [ChapterType.text] par défaut si la valeur n'est pas reconnue.
  static ChapterType fromFirestore(String value) {
    switch (value) {
      case 'pdf':
        return ChapterType.pdf;
      case 'video':
        return ChapterType.video;
      case 'link':
        return ChapterType.link;
      default:
        return ChapterType.text;
    }
  }
}

/// Profil actif dans le module Cours, utilisé par `CoursesController` pour
/// basculer entre l'interface étudiant (catalogue, progression) et l'interface
/// enseignant (création, gestion des chapitres, statistiques).
enum CourseRole { student, teacher }

/// Modèle principal d'un cours stocké dans la collection `courses`.
/// Regroupe les métadonnées descriptives, les compteurs dénormalisés
/// (`chaptersCount`, `enrollmentsCount`) et l'état de publication.
class Course {
  final String id;
  final String teacherId;
  String teacherName;
  bool teacherVerified;
  String title;
  String subject;
  String level;
  String description;

  /// Traductions de la description générées par l'assistant IA, indexées par
  /// code de langue (`en`, `ar`, `es`). Vide tant que l'enseignant n'a pas
  /// lancé « Traduire le cours ». Remplacé par copie lors d'une mise à jour.
  Map<String, String> descriptionTranslations;
  String? coverImageUrl;
  int chaptersCount;
  bool isPublished;
  int enrollmentsCount;
  final DateTime createdAt;

  Course({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.teacherVerified,
    required this.title,
    required this.subject,
    required this.level,
    required this.description,
    this.descriptionTranslations = const {},
    this.coverImageUrl,
    this.chaptersCount = 0,
    this.isPublished = false,
    this.enrollmentsCount = 0,
    required this.createdAt,
  });

  /// Retourne la description dans la langue [languageCode] si une traduction
  /// existe, sinon la description originale (français).
  String descriptionIn(String? languageCode) {
    if (languageCode == null) return description;
    return descriptionTranslations[languageCode] ?? description;
  }

  /// Retourne une copie du cours en remplaçant uniquement les champs fournis,
  /// tout en conservant l'identifiant, l'auteur et la date de création d'origine.
  Course copyWith({
    String? title,
    String? subject,
    String? level,
    String? description,
    Map<String, String>? descriptionTranslations,
    String? coverImageUrl,
    int? chaptersCount,
    bool? isPublished,
    int? enrollmentsCount,
  }) {
    return Course(
      id: id,
      teacherId: teacherId,
      teacherName: teacherName,
      teacherVerified: teacherVerified,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      level: level ?? this.level,
      description: description ?? this.description,
      descriptionTranslations:
          descriptionTranslations ?? this.descriptionTranslations,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      chaptersCount: chaptersCount ?? this.chaptersCount,
      isPublished: isPublished ?? this.isPublished,
      enrollmentsCount: enrollmentsCount ?? this.enrollmentsCount,
      createdAt: createdAt,
    );
  }
}

/// Modèle d'un chapitre appartenant à la sous-collection `courses/{id}/chapters`.
/// Le champ [order] définit sa position d'affichage et est recalculé lors des
/// suppressions ou des réordonnancements dans `CoursesController`.
class Chapter {
  final String id;
  String title;
  final ChapterType type;

  /// Corps du chapitre selon [type] : texte rédigé (`text`), URI du document (`pdf`),
  /// lien YouTube (`video`) ou URL web externe (`link`).
  String? content;

  /// Traductions du contenu rédigé (`text`) générées par l'assistant IA,
  /// indexées par code de langue (`en`, `ar`, `es`). Remplacé par copie
  /// lors d'une mise à jour (le contenu ne référence jamais une map constante).
  Map<String, String> translations;
  int durationMin;
  int order;

  Chapter({
    required this.id,
    required this.title,
    required this.type,
    this.content,
    this.translations = const {},
    required this.durationMin,
    required this.order,
  });

  /// Retourne le contenu du chapitre dans la langue [languageCode] si une
  /// traduction existe, sinon le contenu original (français).
  String? contentIn(String? languageCode) {
    if (languageCode == null) return content;
    return translations[languageCode] ?? content;
  }
}

/// Notification in-app destinée à un étudiant inscrit, créée par le contrôleur
/// lorsqu'un enseignant publie un cours ou ajoute un chapitre
/// (collection Firestore `notifications`, lecture temps réel côté étudiant).
class CourseNotification {
  final String id;

  /// Destinataire : identifiant de l'étudiant inscrit au cours.
  final String userId;

  /// Auteur de l'action (identifiant de l'enseignant), utilisé par les règles
  /// de sécurité pour vérifier la provenance de la notification.
  final String fromId;
  final String courseId;
  final String courseTitle;

  /// Type d'événement : `new_chapter` (chapitre ajouté) ou `course_published`
  /// (cours publié dans le catalogue).
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  bool read;

  CourseNotification({
    required this.id,
    required this.userId,
    required this.fromId,
    required this.courseId,
    required this.courseTitle,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
  });

  /// Icône Material associée au type de notification dans la cloche du module.
  IconData get icon {
    switch (type) {
      case 'course_published':
        return Icons.publish_rounded;
      case 'quiz_published':
        return Icons.quiz_rounded;
      case 'assignment_published':
        return Icons.assignment_rounded;
      case 'document_published':
        return Icons.folder_rounded;
      case 'submission_graded':
        return Icons.grading_rounded;
      default:
        return Icons.note_add_rounded;
    }
  }
}

/// Modèle d'inscription reliant un étudiant à un cours (`courseId` + `studentId`).
/// Mémorise la liste des chapitres validés pour le calcul du taux d'avancement
/// ainsi que le dernier chapitre ouvert pour la reprise directe de lecture.
class Enrollment {
  final String courseId;
  final String studentId;
  final String studentName;
  final List<String> completedChapterIds;

  /// Identifiant du dernier chapitre consulté, utilisé pour reprendre la lecture.
  String? lastChapterId;
  DateTime lastAccess;

  Enrollment({
    required this.courseId,
    required this.studentId,
    required this.studentName,
    required this.completedChapterIds,
    this.lastChapterId,
    required this.lastAccess,
  });
}

/// Agrégat statistique mesurant l'achèvement d'un chapitre donné parmi les
/// inscrits du cours correspondant, exploité dans la vue analytique enseignant.
class ChapterCompletionStat {
  final Course course;
  final Chapter chapter;
  final int completedCount;
  final int enrolledCount;

  const ChapterCompletionStat({
    required this.course,
    required this.chapter,
    required this.completedCount,
    required this.enrolledCount,
  });

  /// Ratio d'étudiants inscrits ayant terminé ce chapitre, compris entre `0.0` et `1.0`.
  double get rate => enrolledCount == 0 ? 0 : completedCount / enrolledCount;
}
