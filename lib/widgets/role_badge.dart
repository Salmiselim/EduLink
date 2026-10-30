import 'package:flutter/material.dart';
import 'forum_ui.dart';

/// Badge distinctif indiquant le rôle de l'auteur d'une publication (`'teacher'` ou `'student'`).
/// S'appuie sur `ForumPill` et est affiché dans `PostCard`, `AnswerCard` et `QuestionDetailScreen`.
class RoleBadge extends StatelessWidget {
  /// Chaîne représentant le rôle de l'auteur (`'student'` ou `'teacher'`).
  final String role;

  const RoleBadge({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final isTeacher = role == 'teacher';
    return ForumPill(
      label: isTeacher ? 'Enseignant vérifié' : 'Étudiant',
      color: isTeacher ? ForumColors.primary : ForumColors.muted,
      background: isTeacher ? ForumColors.infoBg : ForumColors.neutralBg,
      icon: isTeacher ? Icons.verified_rounded : Icons.school_outlined,
    );
  }
}
