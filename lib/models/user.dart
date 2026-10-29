enum ForumRole { student, teacher }

class ForumUser {
  final String id;
  final String name;
  final ForumRole role;
  final String? avatarUrl;
  final String? title;

  const ForumUser({
    required this.id,
    required this.name,
    required this.role,
    this.avatarUrl,
    this.title,
  });

  bool get isTeacher => role == ForumRole.teacher;
  bool get isStudent => role == ForumRole.student;
  String get roleString => isTeacher ? 'teacher' : 'student';
}
