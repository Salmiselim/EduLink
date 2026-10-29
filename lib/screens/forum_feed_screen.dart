import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/forum_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/forum_ui.dart';
import '../widgets/post_card.dart';

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
    final posts = provider.filteredPosts;
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
          // Bascule de rôle simulé (RoleAware : Étudiant / Enseignant vérifié)
          Padding(
            padding: const EdgeInsets.only(right: 8),
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
          // Recherche + filtres par cours
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

                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: provider.courses.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final course = provider.courses[index];
                      final isSelected = provider.selectedCourse == course;
                      return ChoiceChip(
                        label: Text(
                          course,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : ForumColors.textSecondary,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: ForumColors.primary,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: isSelected
                              ? ForumColors.primary
                              : ForumColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        showCheckmark: false,
                        onSelected: (_) => provider.setSelectedCourse(course),
                      );
                    },
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
                      itemCount: posts.length,
                      itemBuilder: (context, index) =>
                          PostCard(post: posts[index]),
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
