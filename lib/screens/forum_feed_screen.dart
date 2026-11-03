import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/forum_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/forum_ui.dart';
import '../widgets/post_card.dart';
import '../widgets/role_badge.dart';

/// Onglet Forum (M3) : AppBar du module + fil de questions.
class ForumFeedScreen extends StatefulWidget {
  const ForumFeedScreen({super.key});

  @override
  State<ForumFeedScreen> createState() => _ForumFeedScreenState();
}

class _ForumFeedScreenState extends State<ForumFeedScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: context.read<ForumProvider>().searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    _searchController.clear();
    context.read<ForumProvider>().resetFilters();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ForumProvider>();
    final posts = provider.visiblePosts;
    final pendingCount = provider.pendingPosts.length;
    final isTeacher = provider.isTeacher;

    return Scaffold(
      backgroundColor: ForumColors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const ForumModuleTitle(
          icon: Icons.forum_rounded,
          title: 'EduLink · Forum',
          subtitle: 'Questions, réponses & réactions',
        ),
        actions: [
          // État de la synchronisation Firebase (visible seulement une fois connecté)
          if (provider.isOnline)
            Tooltip(
              message: provider.lastSyncError ?? 'Synchronisé avec Firebase',
              child: Icon(
                provider.lastSyncError == null
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
                size: 20,
                color: provider.lastSyncError == null
                    ? ForumColors.success
                    : ForumColors.warning,
              ),
            ),
          // Connecté : le rôle vient du compte Firebase (non modifiable ici).
          if (provider.isOnline)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8),
              child: RoleBadge(role: provider.currentUser.roleString),
            )
          // Hors connexion : bascule de rôle simulé (Étudiant / Enseignant vérifié)
          else
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: ActionChip(
              tooltip:
                  'Changer de rôle simulé (RoleAware : Étudiant / Enseignant vérifié)',
              onPressed: () => provider.setRole(
                isTeacher ? ForumRole.student : ForumRole.teacher,
              ),
              backgroundColor:
                  isTeacher ? ForumColors.infoBg : ForumColors.neutralBg,
              avatar: Icon(
                isTeacher ? Icons.verified_rounded : Icons.school_outlined,
                size: 16,
                color: isTeacher
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF475569),
              ),
              label: Text(
                isTeacher ? 'Rôle: Enseignant' : 'Rôle: Étudiant',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isTeacher
                      ? const Color(0xFF1D4ED8)
                      : const Color(0xFF334155),
                ),
              ),
            ),
          ),
          // Boîte « questions à traiter » : réservée à l'enseignant
          if (isTeacher)
            IconButton(
              tooltip: 'Questions à traiter',
              onPressed: () =>
                  Navigator.pushNamed(context, ForumRoutes.forumInbox),
              icon: Badge(
                label: Text('$pendingCount'),
                isLabelVisible: pendingCount > 0,
                child: const Icon(
                  Icons.inbox_rounded,
                  color: ForumColors.primary,
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Recherche + filtres (cours, état, tag)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: provider.setSearchQuery,
                  style: const TextStyle(
                    fontSize: 14,
                    color: ForumColors.textSecondary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Rechercher une question...',
                    hintStyle: const TextStyle(
                      color: ForumColors.muted,
                      fontSize: 13.5,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: ForumColors.muted,
                    ),
                    suffixIcon: provider.searchQuery.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Effacer la recherche',
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: ForumColors.muted,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              provider.setSearchQuery('');
                            },
                          ),
                    filled: true,
                    fillColor: ForumColors.scaffold,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: ForumColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: ForumColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: ForumColors.primary, width: 1.6),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Filtre par cours
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: provider.courses.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final course = provider.courses[index];
                      return _FilterChip(
                        label: course,
                        selected: provider.selectedCourse == course,
                        onSelected: () => provider.setSelectedCourse(course),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 8),

                // Filtre par état + tag actif
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'Toutes',
                        selected:
                            provider.statusFilter == ForumStatusFilter.all,
                        onSelected: () =>
                            provider.setStatusFilter(ForumStatusFilter.all),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Sans réponse',
                        selected: provider.statusFilter ==
                            ForumStatusFilter.unanswered,
                        onSelected: () => provider
                            .setStatusFilter(ForumStatusFilter.unanswered),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Résolues',
                        selected:
                            provider.statusFilter == ForumStatusFilter.resolved,
                        onSelected: () => provider
                            .setStatusFilter(ForumStatusFilter.resolved),
                      ),
                      if (provider.tagFilter != null) ...[
                        const SizedBox(width: 8),
                        InputChip(
                          label: Text(
                            '#${provider.tagFilter}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: ForumColors.primary,
                            ),
                          ),
                          backgroundColor: ForumColors.infoBg,
                          side: const BorderSide(color: ForumColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          deleteIconColor: ForumColors.primary,
                          onDeleted: () => provider.setTagFilter(null),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Ordre du fil : récentes, mieux notées, populaires
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Center(
                          child: Icon(
                            Icons.sort_rounded,
                            size: 18,
                            color: ForumColors.muted,
                          ),
                        ),
                      ),
                      _FilterChip(
                        label: 'Récentes',
                        selected: provider.sortOrder == ForumSortOrder.recent,
                        onSelected: () =>
                            provider.setSortOrder(ForumSortOrder.recent),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Mieux notées',
                        selected: provider.sortOrder == ForumSortOrder.topRated,
                        onSelected: () =>
                            provider.setSortOrder(ForumSortOrder.topRated),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Populaires',
                        selected: provider.sortOrder == ForumSortOrder.popular,
                        onSelected: () =>
                            provider.setSortOrder(ForumSortOrder.popular),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Liste des questions (tirer vers le bas pour rafraîchir)
          Expanded(
            child: RefreshIndicator(
              color: ForumColors.primary,
              onRefresh: provider.refresh,
              child: posts.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        ForumEmptyState(
                          icon: Icons.search_off_rounded,
                          title: provider.hasActiveFilters
                              ? 'Aucune question trouvée'
                              : 'Aucune question pour le moment',
                          subtitle: provider.hasActiveFilters
                              ? 'Aucune question ne correspond à votre recherche.'
                              : 'Soyez le premier à poser une question !',
                          action: provider.hasActiveFilters
                              ? TextButton.icon(
                                  onPressed: _resetFilters,
                                  icon: const Icon(
                                    Icons.filter_alt_off_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Réinitialiser les filtres',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 12, bottom: 88),
                      itemCount: posts.length + (provider.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= posts.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: OutlinedButton.icon(
                              onPressed: provider.loadMore,
                              icon: const Icon(Icons.expand_more_rounded),
                              label: const Text(
                                'Charger plus de questions',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          );
                        }
                        return PostCard(post: posts[index]);
                      },
                    ),
            ),
          ),
        ],
      ),

      // FAB : Poser une question
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, ForumRoutes.forumAsk),
        backgroundColor: ForumColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Poser une question'),
      ),
    );
  }
}

/// Puce de filtre : bleue quand sélectionnée, blanche avec bordure sinon.
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : ForumColors.textSecondary,
        ),
      ),
      selected: selected,
      selectedColor: ForumColors.primary,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? ForumColors.primary : ForumColors.border,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      showCheckmark: false,
      onSelected: (_) => onSelected(),
    );
  }
}
