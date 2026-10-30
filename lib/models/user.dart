/// Rôles supportés au sein du Forum pour distinguer étudiants et enseignants.
enum ForumRole { student, teacher }

/// Modèle représentant l'utilisateur actif dans `ForumProvider`.
/// Permet d'associer un auteur aux publications et de contrôler l'accès aux
/// fonctionnalités réservées aux enseignants (vérification de réponses et boîte de réception).
class ForumUser {
  /// Identifiant unique de l'utilisateur.
  final String id;

  /// Nom complet affiché sur les questions et réponses publiées.
  final String name;

  /// Rôle typé déterminant les permissions dans le forum.
  final ForumRole role;

  /// URL optionnelle de la photo de profil.
  final String? avatarUrl;

  /// Titre académique ou fonctionnel optionnel.
  final String? title;

  const ForumUser({
    required this.id,
    required this.name,
    required this.role,
    this.avatarUrl,
    this.title,
  });

  /// Retourne `true` si l'utilisateur est un enseignant.
  bool get isTeacher => role == ForumRole.teacher;

  /// Retourne `true` si l'utilisateur est un étudiant.
  bool get isStudent => role == ForumRole.student;

  /// Convertit l'énumération [role] en chaîne compatible avec `Post.authorRole` et `Answer.authorRole`.
  String get roleString => isTeacher ? 'teacher' : 'student';
}
