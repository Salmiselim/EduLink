import 'package:flutter/material.dart';

/// Modèles de données immuables de la fonctionnalité Évaluations.
/// Représente les entités métier correspondant aux collections Firestore
/// (`quizzes`, `quiz_attempts`, `assignments`, `submissions`, `documents`)
/// ainsi que les structures dédiées au carnet de notes et aux notifications.

/// Rôle de l'utilisateur courant déterminant les droits d'affichage et d'édition.
enum UserRole {
  student,
  teacher;

  /// Libellé lisible affiché dans l'interface selon le rôle actif.
  String get label => this == UserRole.teacher ? 'Enseignant' : 'Étudiant';
}

/// Format de question pris en charge dans un quiz (`qcm` ou `vrai_faux`).
enum QuestionType {
  qcm,
  vraiFaux;

  /// Identifiant technique stocké dans le schéma de données (`qcm` | `vrai_faux`).
  String get code => this == QuestionType.qcm ? 'qcm' : 'vrai_faux';

  /// Intitulé affiché sur les puces et dans l'assistant de création de quiz.
  String get label => this == QuestionType.qcm ? 'QCM' : 'Vrai / Faux';
}

/// Répertoire thématique de classement d'un support de cours.
enum DocumentFolder {
  polycopies,
  corriges,
  annales;

  /// Nom du dossier affiché dans les filtres `ChoiceChip` et les cartes de documents.
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

  /// Icône Material associée visuellement à chaque type de ressource pédagogique.
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

  /// Couleur distinctive utilisée pour l'icône et le badge de catégorie du document.
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

/// État d'avancement d'une copie déposée par un étudiant (`submitted` ou `graded`).
enum SubmissionStatus {
  submitted,
  graded;

  /// Texte de statut affiché dans la file de correction et le détail des copies.
  String get label =>
      this == SubmissionStatus.graded ? 'Corrigée' : 'À corriger';

  /// Couleur sémantique associée à l'état de correction (vert si notée, ambre sinon).
  Color get color => this == SubmissionStatus.graded
      ? const Color(0xFF16A34A)
      : const Color(0xFFD97706);
}

/// Projection légère d'un cours rattaché aux évaluations, permettant de lier
/// quiz, devoirs et documents sans dépendre directement des modèles complets de cours.
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

/// Question individuelle composant un [Quiz], contenant l'énoncé, les options de réponse,
/// les indices des réponses exactes, le barème en points et l'explication de correction.
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

  /// Indique si la question attend plusieurs réponses exactes simultanément.
  bool get isMultiple => correct.length > 1;

  /// Retourne une copie immuable mise à jour lors de l'édition dans `QuizWizardScreen`.
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

/// Entité représentant un quiz chronométré rattaché à un cours (`quizzes`),
/// avec fenêtre de disponibilité, limite de tentatives et statut de publication.
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

  /// Somme totale des points des questions, utilisée pour normaliser le score sur 20.
  double get totalPoints =>
      questions.fold(0, (sum, q) => sum + q.points);

  /// Produit une nouvelle instance de [Quiz] avec les champs modifiés.
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

/// Tentative de passage d'un quiz par un étudiant (`quiz_attempts`), enregistrant
/// les choix cochés par question, l'horodatage de début/fin et la note calculée sur 20.
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

  /// Vrai lorsque la tentative a été soumise et corrigée automatiquement.
  bool get isSubmitted => submittedAt != null;

  /// Génère une copie mise à jour lors de la sauvegarde intermédiaire ou de la soumission finale.
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

/// Devoir ou travail pratique créé par un enseignant (`assignments`), définissant
/// les consignes, les pièces jointes, la date limite, la note maximale et l'autorisation de retard.
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

  /// Retourne une copie modifiée du devoir lors d'une mise à jour par l'enseignant.
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

/// Dépôt remis par un étudiant pour un [Assignment] (`submissions`), conservant
/// les fichiers joints, le drapeau `isLate` de détection de retard et la correction éventuelle.
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

  /// Produit une nouvelle instance lors d'un redépôt étudiant ou de la notation enseignant.
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

/// Ressource documentaire associée à un cours (`documents`), classée dans un [DocumentFolder]
/// avec date de visibilité et suivi du nombre de téléchargements.
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

  /// Crée une copie modifiée du document (édition des champs ou incrément de `downloadsCount`).
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

/// Ligne consolidée du carnet de notes regroupant quiz et devoirs pour un couple
/// étudiant / cours, exploitée par la vue carnet et par le générateur d'export CSV.
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

/// Notification interne enregistrée par le contrôleur lors des événements clés
/// (publication d'un quiz ou devoir, remise d'une copie, publication d'une note).
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
