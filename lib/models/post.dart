/// Modèle de données représentant une question ou annonce publiée sur le Forum.
/// Stocké dans `ForumProvider` et rendu dans `PostCard` ainsi que `QuestionDetailScreen`.
class Post {
  /// Identifiant unique de la publication, transmis en argument à la route `ForumRoutes.forumQuestion`.
  final String id;

  /// Nom complet de l'auteur de la publication.
  final String authorName;

  /// Rôle de l'auteur (`'student'` ou `'teacher'`) utilisé par `RoleBadge` et `ForumAvatar`.
  final String authorRole;

  /// Intitulé du cours associé permettant le filtrage thématique dans le fil.
  final String courseName;

  /// Titre synthétique de la question.
  final String title;

  /// Description détaillée du problème ou de l'annonce.
  final String body;

  /// Compteur de réponses rattachées, incrémenté par `ForumProvider.addAnswer`.
  int answersCount;

  /// Horodatage de publication formaté via `formatTimeAgo`.
  final DateTime createdAt;

  Post({
    required this.id,
    required this.authorName,
    this.authorRole = 'student',
    required this.courseName,
    required this.title,
    required this.body,
    this.answersCount = 0,
    required this.createdAt,
  });

  /// Indique si la publication émane d'un enseignant.
  bool get isTeacher => authorRole == 'teacher';
}
