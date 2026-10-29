import 'package:flutter/foundation.dart';
import '../data/mock_forum_data.dart';
import '../models/answer.dart';
import '../models/post.dart';
import '../models/user.dart';

class ForumProvider with ChangeNotifier {
  static const String allCourses = 'Tous les cours';

  // Utilisateurs de test : le vrai rôle viendra de users.role (Firebase Auth, M1).
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

  late final List<Post> _posts;
  late final List<Answer> _answers;
  String _searchQuery = '';
  String _selectedCourse = allCourses;
  ForumUser _currentUser = _testStudent;
  int _idCounter = 0;

  ForumProvider() {
    _posts = MockForumData.getInitialPosts();
    _answers = MockForumData.getInitialAnswers();
  }

  // ---------------------------------------------------------------- Getters
  List<String> get courses => MockForumData.coursesList;
  String get searchQuery => _searchQuery;
  String get selectedCourse => _selectedCourse;
  ForumUser get currentUser => _currentUser;
  bool get isTeacher => _currentUser.isTeacher;

  bool get hasActiveFilters =>
      _searchQuery.trim().isNotEmpty || _selectedCourse != allCourses;

  // ---------------------------------------------------------- Rôle de test
  void setRole(ForumRole role) {
    if (role == _currentUser.role) return;
    _currentUser = role == ForumRole.teacher ? _testTeacher : _testStudent;
    notifyListeners();
  }

  // ---------------------------------------------------------------- Filtres
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCourse(String course) {
    _selectedCourse = course;
    notifyListeners();
  }

  void resetFilters() {
    _searchQuery = '';
    _selectedCourse = allCourses;
    notifyListeners();
  }

  /// Simule un rafraîchissement (sera remplacé par un appel Firestore).
  Future<void> refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    notifyListeners();
  }

  // ------------------------------------------------------------------ Posts
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

  /// Retrouve une question quel que soit le filtre actif.
  Post? getPostById(String id) {
    final index = _posts.indexWhere((p) => p.id == id);
    return index == -1 ? null : _posts[index];
  }

  /// Questions d'étudiants sans réponse de l'enseignant ni réponse vérifiée.
  List<Post> get pendingPosts {
    return _posts.where((post) {
      if (post.isTeacher) return false;
      final answers = _answers.where((a) => a.postId == post.id);
      return !answers.any((a) => a.isTeacher || a.isTeacherVerified);
    }).toList();
  }

  /// Crée une question et renvoie son id (pour ouvrir son détail).
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

  // ---------------------------------------------------------------- Réponses
  /// Réponses d'une question : les réponses vérifiées d'abord.
  List<Answer> getAnswersForPost(String postId) {
    final all = _answers.where((a) => a.postId == postId).toList();
    return [
      ...all.where((a) => a.isTeacherVerified),
      ...all.where((a) => !a.isTeacherVerified),
    ];
  }

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

  /// Seul un enseignant peut vérifier (ou retirer la vérification d')une réponse.
  void toggleVerifyAnswer(String answerId) {
    if (!_currentUser.isTeacher) return;
    final index = _answers.indexWhere((a) => a.id == answerId);
    if (index == -1) return;

    final ans = _answers[index];
    ans.isTeacherVerified = !ans.isTeacherVerified;
    notifyListeners();
  }
}
