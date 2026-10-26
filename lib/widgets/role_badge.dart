import 'package:flutter/material.dart';

class RoleBadge extends StatelessWidget {
  final String role; // 'student' | 'teacher'

  const RoleBadge({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final isTeacher = role == 'teacher';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isTeacher
            ? Colors.amber.shade100
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTeacher ? Colors.amber.shade600 : Colors.blue.shade300,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isTeacher ? Icons.verified : Icons.school_outlined,
            size: 13,
            color: isTeacher ? Colors.amber.shade900 : Colors.blue.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            isTeacher ? 'Enseignant' : 'Étudiant',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isTeacher ? Colors.amber.shade900 : Colors.blue.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
