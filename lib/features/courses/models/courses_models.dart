import 'package:flutter/material.dart';

// ============================================================================
// MODÈLES DE DONNÉES — MODULE M2 : COURS
// Correspondent aux collections Firestore du plan d'équipe (page 5) :
// courses · courses/{id}/chapters (sous-collection) · enrollments
// ============================================================================

/// Type de contenu d'un chapitre (`chapters.type` : text | pdf | video | link)
enum ChapterType { text, pdf, video, link }

extension ChapterTypeX on ChapterType {
  /// Libellé affichable dans l'interface
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

  /// Valeur stockée dans Firestore
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

  /// Icône Material (variantes `_rounded` — charte graphique)
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

  /// Couleur sémantique du type (badge à 10 % d'opacité)
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

  Color get background => color.withValues(alpha: 0.1);

  /// Parse la valeur Firestore vers l'enum (fallback : texte)
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

/// Rôle de l'utilisateur connecté (simulation du `users.role` géré par M1)
enum CourseRole { student, teacher }

/// Un cours de la collection `courses`
class Course {
  final String id;
  final String teacherId;
  String teacherName;
  bool teacherVerified;
  String title;
  String subject;
  String level;
  String description;
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
    this.coverImageUrl,
    this.chaptersCount = 0,
    this.isPublished = false,
    this.enrollmentsCount = 0,
    required this.createdAt,
  });

  Course copyWith({
    String? title,
    String? subject,
    String? level,
    String? description,
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
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      chaptersCount: chaptersCount ?? this.chaptersCount,
      isPublished: isPublished ?? this.isPublished,
      enrollmentsCount: enrollmentsCount ?? this.enrollmentsCount,
      createdAt: createdAt,
    );
  }
}

/// Un chapitre de la sous-collection `courses/{id}/chapters`
class Chapter {
  final String id;
  String title;
  final ChapterType type;

  /// Contenu selon le type : texte brut (`text`), URL du fichier (`pdf`),
  /// URL YouTube (`video`) ou URL externe (`link`)
  String? content;
  int durationMin;
  int order;

  Chapter({
    required this.id,
    required this.title,
    required this.type,
    this.content,
    required this.durationMin,
    required this.order,
  });
}

/// Une inscription de la collection `enrollments`
/// (id Firestore = `courseId_studentId`, donc unique)
class Enrollment {
  final String courseId;
  final String studentId;
  final String studentName;
  final List<String> completedChapterIds;

  /// Dernier chapitre consulté — « reprise là où l'on s'est arrêté »
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

/// Statistique de complétion d'un chapitre (tableau de bord enseignant — Métier 3)
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

  /// Taux de complétion du chapitre (0.0 → 1.0)
  double get rate => enrolledCount == 0 ? 0 : completedCount / enrolledCount;
}
