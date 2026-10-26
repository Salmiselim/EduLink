import 'package:flutter/foundation.dart';
import '../data/mock_forum_data.dart';
import '../models/answer.dart';
import '../models/post.dart';

class ForumProvider with ChangeNotifier {
  late List<Post> _posts;
  late List<Answer> _answers;
  String _searchQuery = '';
  String _selectedCourse = 'Tous les cours';

  ForumProvider() {
    _posts = MockForumData.getInitialPosts();
    _answers = MockForumData.getInitialAnswers();
  }

  // Getters
  List<String> get courses => MockForumData.coursesList;
  String get searchQuery => _searchQuery;
  String get selectedCourse => _selectedCourse;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCourse(String course) {
    _selectedCourse = course;
    notifyListeners();
  }

  // Filtered posts (simple search + course filter)
  List<Post> get filteredPosts {
    return _posts.where((post) {
      if (_selectedCourse != 'Tous les cours' &&
          post.courseName != _selectedCourse) {
        return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase();
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

  List<Answer> getAnswersForPost(String postId) {
    return _answers.where((a) => a.postId == postId).toList();
  }

  void createPost({
    required String title,
    required String body,
    required String courseName,
  }) {
    final newPost = Post(
      id: 'post_${DateTime.now().millisecondsSinceEpoch}',
      authorName: 'Selim Riahi',
      authorRole: 'student',
      courseName: courseName,
      title: title,
      body: body,
      answersCount: 0,
      createdAt: DateTime.now(),
    );

    _posts.insert(0, newPost);
    notifyListeners();
  }

  void addAnswer({
    required String postId,
    required String body,
  }) {
    final newAnswer = Answer(
      id: 'ans_${DateTime.now().millisecondsSinceEpoch}',
      postId: postId,
      authorName: 'Selim Riahi',
      authorRole: 'student',
      body: body,
      votesCount: 0,
      createdAt: DateTime.now(),
    );

    _answers.add(newAnswer);

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
}
