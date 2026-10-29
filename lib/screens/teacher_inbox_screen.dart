import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/forum_provider.dart';
import '../widgets/post_card.dart';

/// Boîte « questions à traiter » : questions d'étudiants sans réponse
/// de l'enseignant. Réservée au rôle enseignant.
class TeacherInboxScreen extends StatelessWidget {
  const TeacherInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ForumProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Questions à traiter',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(ForumProvider provider) {
    if (!provider.isTeacher) {
      return const _Message(
        icon: Icons.lock_outline,
        text: 'Cet espace est réservé aux enseignants.',
      );
    }

    final pending = provider.pendingPosts;
    if (pending.isEmpty) {
      return const _Message(
        icon: Icons.check_circle_outline,
        text: 'Toutes les questions ont été traitées.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: pending.length,
      itemBuilder: (context, index) => PostCard(post: pending[index]),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
