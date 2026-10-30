import 'package:flutter/foundation.dart';
import '../data/mock_forum_data.dart';
import '../models/answer.dart';
import '../models/post.dart';
import '../models/user.dart';

/// Gestionnaire d'état central du Forum basé sur `ChangeNotifier`.
/// Centralise la liste des questions (`Post`), des réponses (`Answer`), les filtres
/// de recherche et le profil actif, puis notifie les écrans abonnés via `notifyListeners()`.
class ForumProvider with ChangeNotifier {
  /// Libellé représentant l'absence de filtre sur un cours particulier.
  static const String allCourses = 'Tous les cours';

  // Profils simulés permettant de tester les droits étudiant et enseignant localement.
  static const ForumUser _testStudent = ForumUser(
    id: 'user_selim',
    name: 'Selim Riahi',
    role: ForumRole.student,
  );
  static const ForumUser _testTeacher = ForumUser(
    id: 'user_sarah',
    name: 'Dr. Sarah Mansour',
    role: ForumRole.teacher,
    title: 'Enseignante',
  );

  /// Collection en mémoire des questions publiées sur le forum.
  late final List<Post> _posts;

  /// Collection en mémoire de toutes les réponses associées aux questions par `postId`.
  late final List<Answer> _answers;

  /// Texte de recherche courant saisi dans `ForumFeedScreen`.
  String _searchQuery = '';

  /// Cours actuellement sélectionné dans les puces de filtrage.
  String _selectedCourse = allCourses;

  /// Utilisateur courant déterminant l'auteur des publications et les droits de modération.
  ForumUser _currentUser = _testStudent;

  /// Compteur incrémental garantissant l'unicité des identifiants générés localement.
  int _idCounter = 0;

  /// Initialise l'état du forum à partir du jeu de données locales `MockForumData`.
  ForumProvider() {
    _posts = MockForumData.getInitialPosts();
    _answers = MockForumData.getInitialAnswers();
  }

  /// Liste des intitulés de cours proposés dans les filtres et le formulaire de création.
  List<String> get courses => MockForumData.coursesList;

  /// Requête de recherche textuelle active.
  String get searchQuery => _searchQuery;

  /// Filtre de cours actif (`allCourses` par défaut).
  String get selectedCourse => _selectedCourse;

  /// Profil utilisateur actif dans la session du forum.
  ForumUser get currentUser => _currentUser;

  /// Indique si le profil courant dispose des privilèges enseignant.
  bool get isTeacher => _currentUser.isTeacher;

  /// Indique si au moins un critère de filtrage (mot-clé ou cours) est appliqué.
  bool get hasActiveFilters =>
      _searchQuery.trim().isNotEmpty || _selectedCourse != allCourses;

  /// Bascule entre le profil étudiant et le profil enseignant puis rafraîchit l'interface.
  void setRole(ForumRole role) {
    if (role == _currentUser.role) return;
    _currentUser = role == ForumRole.teacher ? _testTeacher : _testStudent;
    notifyListeners();
  }

  /// Met à jour le mot-clé de recherche et reconstruit la liste filtrée dans `ForumFeedScreen`.
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Applique le filtre sur le cours sélectionné et notifie les widgets observateurs.
  void setSelectedCourse(String course) {
    _selectedCourse = course;
    notifyListeners();
  }

  /// Réinitialise simultanément la recherche textuelle et le filtre de cours.
  void resetFilters() {
    _searchQuery = '';
    _selectedCourse = allCourses;
    notifyListeners();
  }

  /// Simule un rechargement asynchrone déclenché par le `RefreshIndicator` du fil.
  Future<void> refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    notifyListeners();
  }

  /// Retourne la liste des questions filtrées selon le cours sélectionné et le mot-clé
  /// recherché (comparaison insensible à la casse sur le titre, le corps et l'auteur).
  List<Post> get filteredPosts {
    return _posts.where((post) {
      if (_selectedCourse != allCourses && post.courseName != _selectedCourse) {
        return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final matchTitle = post.title.toLowerCase().contains(query);
        final matchBody = post.body.toLowerCase().contains(query);
        final matchAuthor = post.authorName.toLowerCase().contains(query);
        if (!matchTitle && !matchBody && !matchAuthor) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Recherche une question par son identifiant dans la liste complète, indépendamment des filtres actifs.
  Post? getPostById(String id) {
    final index = _posts.indexWhere((p) => p.id == id);
    return index == -1 ? null : _posts[index];
  }

  /// Extrait les questions posées par des étudiants qui n'ont encore reçu ni réponse
  /// d'un enseignant ni réponse marquée comme vérifiée (alimente `TeacherInboxScreen`).
  List<Post> get pendingPosts {
    return _posts.where((post) {
      if (post.isTeacher) return false;
      final answers = _answers.where((a) => a.postId == post.id);
      return !answers.any((a) => a.isTeacher || a.isTeacherVerified);
    }).toList();
  }

  /// Ajoute une nouvelle question en tête du fil au nom de `_currentUser`,
  /// notifie les écouteurs et retourne son identifiant pour la redirection vers `QuestionDetailScreen`.
  String createPost({
    required String title,
    required String body,
    required String courseName,
  }) {
    final id = 'post_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';
    final newPost = Post(
      id: id,
      authorName: _currentUser.name,
      authorRole: _currentUser.roleString,
      courseName: courseName,
      title: title.trim(),
      body: body.trim(),
      answersCount: 0,
      createdAt: DateTime.now(),
    );

    _posts.insert(0, newPost);
    notifyListeners();
    return id;
  }

  /// Récupère les réponses rattachées à [postId] en plaçant en priorité celles
  /// validées par un enseignant (`isTeacherVerified`) en haut de la liste.
  List<Answer> getAnswersForPost(String postId) {
    final all = _answers.where((a) => a.postId == postId).toList();
    return [
      ...all.where((a) => a.isTeacherVerified),
      ...all.where((a) => !a.isTeacherVerified),
    ];
  }

  /// Enregistre une nouvelle réponse sur la question [postId], incrémente son compteur
  /// `answersCount` et déclenche la mise à jour des vues abonnées.
  void addAnswer({
    required String postId,
    required String body,
  }) {
    final text = body.trim();
    if (text.isEmpty) return;

    _answers.add(
      Answer(
        id: 'ans_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}',
        postId: postId,
        authorName: _currentUser.name,
        authorRole: _currentUser.roleString,
        body: text,
        votesCount: 0,
        createdAt: DateTime.now(),
      ),
    );

    final postIndex = _posts.indexWhere((p) => p.id == postId);
    if (postIndex != -1) {
      _posts[postIndex].answersCount++;
    }

    notifyListeners();
  }

  /// Inverse l'état de vote positif (`isUpvoted`) de l'utilisateur sur la réponse [answerId]
  /// et ajuste le compteur `votesCount` en conséquence.
  void toggleVoteAnswer(String answerId) {
    final index = _answers.indexWhere((a) => a.id == answerId);
    if (index == -1) return;

    final ans = _answers[index];
    if (ans.isUpvoted) {
      ans.votesCount--;
      ans.isUpvoted = false;
    } else {
      ans.votesCount++;
      ans.isUpvoted = true;
    }

    notifyListeners();
  }

  /// Marque ou démarque une réponse comme pédagogiquement vérifiée.
  /// Action protégée par le contrôle de rôle `_currentUser.isTeacher`.
  void toggleVerifyAnswer(String answerId) {
    if (!_currentUser.isTeacher) return;
    final index = _answers.indexWhere((a) => a.id == answerId);
    if (index == -1) return;

    final ans = _answers[index];
    ans.isTeacherVerified = !ans.isTeacherVerified;
    notifyListeners();
  }
}
