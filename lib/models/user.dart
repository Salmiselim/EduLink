enum UserRole { student, teacher }

class ForumUser {
  final String id;
  final String name;
  final UserRole role;
  final String? avatarUrl;
  final String? title;

  const ForumUser({
    required this.id,
    required this.name,
    required this.role,
    this.avatarUrl,
    this.title,
  });

  bool get isTeacher => role == UserRole.teacher;
  bool get isStudent => role == UserRole.student;
  String get roleString => isTeacher ? 'teacher' : 'student';
}
