class Post {
  final String id;
  final String authorName;
  final String authorRole; // 'student' | 'teacher'
  final String courseName;
  final String title;
  final String body;
  int answersCount;
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

  bool get isTeacher => authorRole == 'teacher';
}
