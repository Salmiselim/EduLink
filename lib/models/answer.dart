import 'json_helpers.dart';

/// Modèle de données représentant une réponse publiée sous une question du Forum.
/// Géré par `ForumProvider` et affiché via le composant `AnswerCard`.
/// Les réactions (like, utile, instructif) sont stockées à part (`Reaction`).
class Answer {
  /// Identifiant unique de la réponse.
  final String id;

  /// Identifiant de la question parente (`Post.id`) à laquelle cette réponse est rattachée.
  final String postId;

  /// Identifiant de l'auteur (sert aux droits de modification et de suppression).
  final String authorId;

  /// Nom complet de l'auteur affiché dans l'en-tête de `AnswerCard`.
  final String authorName;

  /// Rôle de l'auteur au moment de la publication (`'student'` ou `'teacher'`).
  final String authorRole;

  /// Contenu textuel de la réponse.
  String body;

  /// Extrait de code optionnel joint à la réponse.
  String? codeSnippet;

  /// Langage de l'extrait (clé de `CodeRunnerService.languages`).
  String? codeLanguage;

  /// Indique si la réponse a été validée pédagogiquement par un enseignant.
  bool isTeacherVerified;

  /// Date de la vérification par l'enseignant.
  DateTime? verifiedAt;

  /// Date et heure de création servant au calcul de la durée relative.
  final DateTime createdAt;

  /// Date de la dernière modification (null tant que la réponse n'a pas été éditée).
  DateTime? updatedAt;

  Answer({
    required this.id,
    required this.postId,
    this.authorId = '',
    required this.authorName,
    this.authorRole = 'student',
    required this.body,
    this.codeSnippet,
    this.codeLanguage,
    this.isTeacherVerified = false,
    this.verifiedAt,
    required this.createdAt,
    this.updatedAt,
  });

  /// Retourne `true` lorsque l'auteur de la réponse possède le statut enseignant.
  bool get isTeacher => authorRole == 'teacher';

  /// Indique si la réponse a été modifiée après sa publication.
  bool get isEdited => updatedAt != null;

  /// Indique si un extrait de code non vide est joint.
  bool get hasCode => (codeSnippet ?? '').trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'postId': postId,
        'authorId': authorId,
        'authorName': authorName,
        'authorRole': authorRole,
        'body': body,
        'codeSnippet': codeSnippet,
        'codeLanguage': codeLanguage,
        'isTeacherVerified': isTeacherVerified,
        'verifiedAt': verifiedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Answer.fromJson(Map<String, dynamic> json) {
    return Answer(
      id: json['id'] as String,
      postId: (json['postId'] as String?) ?? '',
      authorId: (json['authorId'] as String?) ?? '',
      authorName: (json['authorName'] as String?) ?? 'Utilisateur',
      authorRole: (json['authorRole'] as String?) ?? 'student',
      body: (json['body'] as String?) ?? '',
      codeSnippet: json['codeSnippet'] as String?,
      codeLanguage: json['codeLanguage'] as String?,
      isTeacherVerified: (json['isTeacherVerified'] as bool?) ?? false,
      verifiedAt: parseDate(json['verifiedAt']),
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(json['updatedAt']),
    );
  }
}
