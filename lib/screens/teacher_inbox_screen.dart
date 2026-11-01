import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/forum_provider.dart';
import '../widgets/forum_ui.dart';
import '../widgets/post_card.dart';

/// Boîte de réception enseignant accessible via la route `ForumRoutes.forumInbox`.
/// Regroupe les questions d'étudiants n'ayant encore reçu ni réponse enseignant ni réponse vérifiée.
class TeacherInboxScreen extends StatelessWidget {
  const TeacherInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Observation de `ForumProvider` afin de retirer automatiquement une question dès qu'elle est traitée.
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

  /// Construit le contenu selon le rôle courant et le nombre de questions en attente.
  Widget _buildBody(ForumProvider provider) {
    // Garde-fou empêchant l'affichage de la liste si le profil actif n'est pas enseignant.
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

    // Réutilise `PostCard` pour permettre d'ouvrir directement le détail de chaque question à traiter.
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      itemCount: pending.length,
      itemBuilder: (context, index) => PostCard(post: pending[index]),
    );
  }
}
