/// Modèle de données représentant une réponse publiée sous une question du Forum.
/// Géré par `ForumProvider` et affiché via le composant `AnswerCard`.
class Answer {
  /// Identifiant unique de la réponse.
  final String id;

  /// Identifiant de la question parente (`Post.id`) à laquelle cette réponse est rattachée.
  final String postId;

  /// Nom complet de l'auteur affiché dans l'en-tête de `AnswerCard`.
  final String authorName;

  /// Rôle de l'auteur au moment de la publication (`'student'` ou `'teacher'`).
  final String authorRole;

  /// Contenu textuel de la réponse.
  final String body;

  /// Nombre total de votes positifs reçus.
  int votesCount;

  /// Indique si l'utilisateur courant a attribué un vote positif à cette réponse.
  bool isUpvoted;

  /// Indique si la réponse a été validée pédagogiquement par un enseignant.
  bool isTeacherVerified;

  /// Date et heure de création servant au calcul de la durée relative.
  final DateTime createdAt;

  Answer({
    required this.id,
    required this.postId,
    required this.authorName,
    this.authorRole = 'student',
    required this.body,
    this.votesCount = 0,
    this.isUpvoted = false,
    this.isTeacherVerified = false,
    required this.createdAt,
  });

  /// Retourne `true` lorsque l'auteur de la réponse possède le statut enseignant.
  bool get isTeacher => authorRole == 'teacher';
}
