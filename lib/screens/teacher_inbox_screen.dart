import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/forum_provider.dart';
import '../widgets/forum_ui.dart';
import '../widgets/post_card.dart';

/// Boîte « questions à traiter » : questions d'étudiants sans réponse
/// de l'enseignant. Réservée au rôle enseignant.
class TeacherInboxScreen extends StatelessWidget {
  const TeacherInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ForumProvider>();

    return Scaffold(
      backgroundColor: ForumColors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const ForumPageTitle('Questions à traiter'),
      ),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(ForumProvider provider) {
    if (!provider.isTeacher) {
      return const Center(
        child: ForumEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Espace réservé',
          subtitle: 'Cet espace est réservé aux enseignants.',
        ),
      );
    }

    final pending = provider.pendingPosts;
    if (pending.isEmpty) {
      return const Center(
        child: ForumEmptyState(
          icon: Icons.check_circle_outline_rounded,
          title: 'Tout est traité',
          subtitle: 'Toutes les questions ont reçu une réponse enseignant.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      itemCount: pending.length,
      itemBuilder: (context, index) => PostCard(post: pending[index]),
    );
  }
}
