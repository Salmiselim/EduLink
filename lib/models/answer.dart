class Answer {
  final String id;
  final String postId;
  final String authorName;
  final String authorRole; // 'student' | 'teacher'
  final String body;
  int votesCount;
  bool isUpvoted;
  bool isTeacherVerified; // « Réponse vérifiée » par l'enseignant du cours
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

  bool get isTeacher => authorRole == 'teacher';
}
