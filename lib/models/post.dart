import 'json_helpers.dart';

/// Statut d'une question : ouverte, ou résolue lorsqu'une réponse est acceptée.
enum PostStatus { open, resolved }

/// Modèle de données représentant une question ou annonce publiée sur le Forum.
/// Stocké dans `ForumProvider` (et sérialisé en JSON pour le stockage local
/// et l'API REST) puis rendu dans `PostCard` et `QuestionDetailScreen`.
class Post {
  /// Identifiant unique de la publication, transmis en argument à la route `ForumRoutes.forumQuestion`.
  final String id;

  /// Identifiant de l'auteur (sert aux droits de modification et de suppression).
  final String authorId;

  /// Nom complet de l'auteur de la publication.
  final String authorName;

  /// Rôle de l'auteur (`'student'` ou `'teacher'`) utilisé par `RoleBadge` et `ForumAvatar`.
  final String authorRole;

  /// Intitulé du cours associé permettant le filtrage thématique dans le fil.
  String courseName;

  /// Titre synthétique de la question.
  String title;

  /// Description détaillée du problème ou de l'annonce.
  String body;

  /// Mots-clés de la question (minuscules, sans doublon, 5 maximum).
  List<String> tags;

  /// Extrait de code optionnel joint à la question.
  String? codeSnippet;

  /// Langage de l'extrait (clé de `CodeRunnerService.languages`, ex. `python`).
  String? codeLanguage;

  /// `open` par défaut ; `resolved` quand l'auteur accepte une réponse.
  PostStatus status;

  /// Identifiant de la réponse acceptée par l'auteur, le cas échéant.
  String? acceptedReplyId;

  /// Compteur de réponses rattachées, tenu à jour par `ForumProvider`.
  int answersCount;

  /// Horodatage de publication formaté via `formatTimeAgo`.
  final DateTime createdAt;

  /// Date de la dernière modification (null tant que la question n'a pas été éditée).
  DateTime? updatedAt;

  Post({
    required this.id,
    this.authorId = '',
    required this.authorName,
    this.authorRole = 'student',
    required this.courseName,
    required this.title,
    required this.body,
    List<String>? tags,
    this.codeSnippet,
    this.codeLanguage,
    this.status = PostStatus.open,
    this.acceptedReplyId,
    this.answersCount = 0,
    required this.createdAt,
    this.updatedAt,
  }) : tags = tags ?? <String>[];

  /// Indique si la publication émane d'un enseignant.
  bool get isTeacher => authorRole == 'teacher';

  /// Indique si la question a été résolue (réponse acceptée).
  bool get isResolved => status == PostStatus.resolved;

  /// Indique si la question a été modifiée après sa publication.
  bool get isEdited => updatedAt != null;

  /// Indique si un extrait de code non vide est joint.
  bool get hasCode => (codeSnippet ?? '').trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        'authorRole': authorRole,
        'courseName': courseName,
        'title': title,
        'body': body,
        'tags': tags,
        'codeSnippet': codeSnippet,
        'codeLanguage': codeLanguage,
        'status': status.name,
        'acceptedReplyId': acceptedReplyId,
        'repliesCount': answersCount,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      authorId: (json['authorId'] as String?) ?? '',
      authorName: (json['authorName'] as String?) ?? 'Utilisateur',
      authorRole: (json['authorRole'] as String?) ?? 'student',
      courseName: (json['courseName'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      tags: parseStringList(json['tags']),
      codeSnippet: json['codeSnippet'] as String?,
      codeLanguage: json['codeLanguage'] as String?,
      status: enumFromName(PostStatus.values, json['status'], PostStatus.open),
      acceptedReplyId: json['acceptedReplyId'] as String?,
      answersCount: (json['repliesCount'] as num?)?.toInt() ?? 0,
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(json['updatedAt']),
    );
  }
}
