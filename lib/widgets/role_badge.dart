import 'package:flutter/material.dart';
import 'forum_ui.dart';

/// Badge de rôle : « Enseignant vérifié » (bleu) / « Étudiant » (neutre).
class RoleBadge extends StatelessWidget {
  final String role; // 'student' | 'teacher'

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
