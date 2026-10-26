import 'package:flutter/material.dart';

// ============================================================================
// MODÈLES DE DONNÉES — MODULE M4 : ÉVALUATIONS (Pages 6-7 du Plan d'équipe)
// Collections Firestore :
// - quizzes · quiz_attempts · assignments · submissions · documents
// ============================================================================

/// Rôle simulé (RoleAware) — `users.role` : student | teacher
enum UserRole {
  student,
  teacher;

  String get label => this == UserRole.teacher ? 'Enseignant' : 'Étudiant';
}

/// Type de question de quiz (`quizzes.questions[].type` : qcm | vrai_faux)
enum QuestionType {
  qcm,
  vraiFaux;

  String get code => this == QuestionType.qcm ? 'qcm' : 'vrai_faux';

  String get label => this == QuestionType.qcm ? 'QCM' : 'Vrai / Faux';
}

/// Dossier d'un document de cours (espace façon Blackboard)
enum DocumentFolder {
  polycopies,
  corriges,
  annales;

  String get label {
    switch (this) {
      case DocumentFolder.polycopies:
        return 'Polycopiés';
      case DocumentFolder.corriges:
        return 'Corrigés';
      case DocumentFolder.annales:
        return 'Annales';
    }
  }

  IconData get icon {
    switch (this) {
      case DocumentFolder.polycopies:
        return Icons.menu_book_rounded;
      case DocumentFolder.corriges:
        return Icons.task_alt_rounded;
      case DocumentFolder.annales:
        return Icons.history_edu_rounded;
    }
  }

  Color get color {
    switch (this) {
      case DocumentFolder.polycopies:
        return const Color(0xFF2563EB);
      case DocumentFolder.corriges:
        return const Color(0xFF16A34A);
      case DocumentFolder.annales:
        return const Color(0xFF7C3AED);
    }
  }
}

/// Statut d'une copie (`submissions.status` : submitted | graded)
enum SubmissionStatus {
  submitted,
  graded;

  String get label =>
      this == SubmissionStatus.graded ? 'Corrigée' : 'À corriger';

  Color get color => this == SubmissionStatus.graded
      ? const Color(0xFF16A34A)
      : const Color(0xFFD97706);
}

/// Cours mock (contrat L4 / L5 avec M2 — jamais d'accès direct aux collections M2)
class LinkedCourse {
  final String id;
  final String title;
  final String subject;
  final String level;
  final String teacherId;
  final String teacherName;

  const LinkedCourse({
    required this.id,
    required this.title,
    required this.subject,
    required this.level,
    required this.teacherId,
    required this.teacherName,
  });
}

class QuizQuestion {
  final String id;
  final QuestionType type;
  final String text;
  final List<String> options;
  final List<int> correct;
  final double points;
  final String explanation;

  const QuizQuestion({
    required this.id,
    required this.type,
    required this.text,
    required this.options,
    required this.correct,
    required this.points,
    required this.explanation,
  });

  bool get isMultiple => correct.length > 1;

  QuizQuestion copyWith({
    QuestionType? type,
    String? text,
    List<String>? options,
    List<int>? correct,
    double? points,
    String? explanation,
  }) {
    return QuizQuestion(
      id: id,
      type: type ?? this.type,
      text: text ?? this.text,
      options: options ?? this.options,
      correct: correct ?? this.correct,
      points: points ?? this.points,
      explanation: explanation ?? this.explanation,
    );
  }
}

/// Collection `quizzes`
class Quiz {
  final String id;
  final String courseId;
  final String courseTitle;
  final String teacherId;
  final String teacherName;
  final String title;
  final int timeLimitMin;
  final int attemptsAllowed;
  final DateTime availableFrom;
  final DateTime dueDate;
  final bool isPublished;
  final List<QuizQuestion> questions;

  const Quiz({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.teacherId,
    required this.teacherName,
    required this.title,
    required this.timeLimitMin,
    required this.attemptsAllowed,
    required this.availableFrom,
    required this.dueDate,
    required this.isPublished,
    required this.questions,
  });

  double get totalPoints =>
      questions.fold(0, (sum, q) => sum + q.points);

  Quiz copyWith({
    String? title,
    String? courseId,
    String? courseTitle,
    int? timeLimitMin,
    int? attemptsAllowed,
    DateTime? availableFrom,
    DateTime? dueDate,
    bool? isPublished,
    List<QuizQuestion>? questions,
  }) {
    return Quiz(
      id: id,
      courseId: courseId ?? this.courseId,
      courseTitle: courseTitle ?? this.courseTitle,
      teacherId: teacherId,
      teacherName: teacherName,
      title: title ?? this.title,
      timeLimitMin: timeLimitMin ?? this.timeLimitMin,
      attemptsAllowed: attemptsAllowed ?? this.attemptsAllowed,
      availableFrom: availableFrom ?? this.availableFrom,
      dueDate: dueDate ?? this.dueDate,
      isPublished: isPublished ?? this.isPublished,
      questions: questions ?? this.questions,
    );
  }
}

/// Collection `quiz_attempts`
class QuizAttempt {
  final String id;
  final String quizId;
  final String studentId;
  final String studentName;
  final int attemptNo;
  final List<List<int>> answers;
  final double? score;
  final DateTime startedAt;
  final DateTime? submittedAt;

  const QuizAttempt({
    required this.id,
    required this.quizId,
    required this.studentId,
    required this.studentName,
    required this.attemptNo,
    required this.answers,
    this.score,
    required this.startedAt,
    this.submittedAt,
  });

  bool get isSubmitted => submittedAt != null;

  QuizAttempt copyWith({
    List<List<int>>? answers,
    double? score,
    DateTime? submittedAt,
  }) {
    return QuizAttempt(
      id: id,
      quizId: quizId,
      studentId: studentId,
      studentName: studentName,
      attemptNo: attemptNo,
      answers: answers ?? this.answers,
      score: score ?? this.score,
      startedAt: startedAt,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }
}

/// Collection `assignments` (dépôts)
class Assignment {
  final String id;
  final String courseId;
  final String courseTitle;
  final String teacherId;
  final String teacherName;
  final String title;
  final String instructions;
  final List<String> attachments;
  final DateTime dueDate;
  final double maxGrade;
  final bool allowLate;

  const Assignment({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.teacherId,
    required this.teacherName,
    required this.title,
    required this.instructions,
    this.attachments = const [],
    required this.dueDate,
    required this.maxGrade,
    required this.allowLate,
  });

  Assignment copyWith({
    String? title,
    String? courseId,
    String? courseTitle,
    String? instructions,
    List<String>? attachments,
    DateTime? dueDate,
    double? maxGrade,
    bool? allowLate,
  }) {
    return Assignment(
      id: id,
      courseId: courseId ?? this.courseId,
      courseTitle: courseTitle ?? this.courseTitle,
      teacherId: teacherId,
      teacherName: teacherName,
      title: title ?? this.title,
      instructions: instructions ?? this.instructions,
      attachments: attachments ?? this.attachments,
      dueDate: dueDate ?? this.dueDate,
      maxGrade: maxGrade ?? this.maxGrade,
      allowLate: allowLate ?? this.allowLate,
    );
  }
}

/// Collection `submissions`
class Submission {
  final String id;
  final String assignmentId;
  final String studentId;
  final String studentName;
  final List<String> fileUrls;
  final String comment;
  final DateTime submittedAt;
  final bool isLate;
  final SubmissionStatus status;
  final double? grade;
  final String? feedback;
  final DateTime? gradedAt;

  const Submission({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.studentName,
    required this.fileUrls,
    required this.comment,
    required this.submittedAt,
    required this.isLate,
    required this.status,
    this.grade,
    this.feedback,
    this.gradedAt,
  });

  Submission copyWith({
    List<String>? fileUrls,
    String? comment,
    DateTime? submittedAt,
    bool? isLate,
    SubmissionStatus? status,
    double? grade,
    String? feedback,
    DateTime? gradedAt,
  }) {
    return Submission(
      id: id,
      assignmentId: assignmentId,
      studentId: studentId,
      studentName: studentName,
      fileUrls: fileUrls ?? this.fileUrls,
      comment: comment ?? this.comment,
      submittedAt: submittedAt ?? this.submittedAt,
      isLate: isLate ?? this.isLate,
      status: status ?? this.status,
      grade: grade ?? this.grade,
      feedback: feedback ?? this.feedback,
      gradedAt: gradedAt ?? this.gradedAt,
    );
  }
}

/// Collection `documents`
class CourseDocument {
  final String id;
  final String courseId;
  final String courseTitle;
  final String teacherId;
  final String teacherName;
  final String title;
  final String description;
  final DocumentFolder folder;
  final String fileUrl;
  final int order;
  final DateTime visibleFrom;
  final int downloadsCount;

  const CourseDocument({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.teacherId,
    required this.teacherName,
    required this.title,
    required this.description,
    required this.folder,
    required this.fileUrl,
    required this.order,
    required this.visibleFrom,
    this.downloadsCount = 0,
  });

  CourseDocument copyWith({
    String? title,
    String? description,
    DocumentFolder? folder,
    String? fileUrl,
    int? order,
    DateTime? visibleFrom,
    int? downloadsCount,
  }) {
    return CourseDocument(
      id: id,
      courseId: courseId,
      courseTitle: courseTitle,
      teacherId: teacherId,
      teacherName: teacherName,
      title: title ?? this.title,
      description: description ?? this.description,
      folder: folder ?? this.folder,
      fileUrl: fileUrl ?? this.fileUrl,
      order: order ?? this.order,
      visibleFrom: visibleFrom ?? this.visibleFrom,
      downloadsCount: downloadsCount ?? this.downloadsCount,
    );
  }
}

/// Ligne du carnet de notes (`GET /courses/:id/gradebook`)
class GradebookRow {
  final String studentId;
  final String studentName;
  final String courseTitle;
  final String itemType;
  final String itemTitle;
  final double? grade;
  final double maxGrade;
  final String status;
  final DateTime? datedAt;

  const GradebookRow({
    required this.studentId,
    required this.studentName,
    required this.courseTitle,
    required this.itemType,
    required this.itemTitle,
    required this.grade,
    required this.maxGrade,
    required this.status,
    this.datedAt,
  });
}

/// Notification mock (contrat L8 — NotificationsService.send)
class EvalNotification {
  final String title;
  final String body;
  final DateTime createdAt;

  const EvalNotification({
    required this.title,
    required this.body,
    required this.createdAt,
  });
}
