import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/forum_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/post_card.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Forum d\'entraide',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF1E293B),
          ),
        ),
        actions: [
          // Boîte « questions à traiter » : réservée à l'enseignant
          if (provider.isTeacher)
            IconButton(
              tooltip: 'Questions à traiter',
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.forumInbox),
              icon: Badge(
                label: Text('$pendingCount'),
                isLabelVisible: pendingCount > 0,
                child: const Icon(Icons.inbox_outlined,
                    color: Color(0xFF1E293B)),
              ),
            ),
          // Sélecteur de rôle : outil de test, absent en version finale
          if (kDebugMode)
            PopupMenuButton<UserRole>(
              tooltip: 'Changer de rôle (mode test)',
              icon: const Icon(Icons.swap_horiz_rounded,
                  color: Color(0xFF1E293B)),
              onSelected: provider.setRole,
              itemBuilder: (context) => [
                CheckedPopupMenuItem<UserRole>(
                  value: UserRole.student,
                  checked: !provider.isTeacher,
                  child: const Text('Étudiant'),
                ),
                CheckedPopupMenuItem<UserRole>(
                  value: UserRole.teacher,
                  checked: provider.isTeacher,
                  child: const Text('Enseignant'),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: provider.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'Rechercher une question...',
                    hintStyle:
                        TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    prefixIcon:
                        const Icon(Icons.search, size: 20, color: Colors.grey),
                    suffixIcon: provider.searchQuery.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Effacer la recherche',
                            icon: const Icon(Icons.close,
                                size: 18, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              provider.setSearchQuery('');
                            },
                          ),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Simple Course Horizontal Chips
                SizedBox(
                  height: 32,
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
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : Colors.blueGrey.shade800,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: Colors.indigo,
                        backgroundColor: const Color(0xFFF1F5F9),
                        showCheckmark: false,
                        onSelected: (_) => provider.setSelectedCourse(course),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Questions List (tirer vers le bas pour rafraîchir)
          Expanded(
            child: RefreshIndicator(
              onRefresh: provider.refresh,
              child: posts.isEmpty
                  ? _EmptyState(
                      hasFilters: provider.hasActiveFilters,
                      onReset: _resetFilters,
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 4, bottom: 80),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        return PostCard(post: posts[index]);
                      },
                    ),
            ),
          ),
        ],
      ),

      // FAB: Poser une question
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Poser une question'),
        onPressed: () => Navigator.pushNamed(context, AppRoutes.forumAsk),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onReset;

  const _EmptyState({required this.hasFilters, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.search_off_rounded, size: 56, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Center(
          child: Text(
            hasFilters
                ? 'Aucune question ne correspond à votre recherche'
                : 'Aucune question pour le moment',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
        if (hasFilters) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Réinitialiser les filtres'),
            ),
          ),
        ],
      ],
    );
  }
}
