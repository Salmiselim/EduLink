import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/forum_provider.dart';
import '../widgets/post_card.dart';
import 'ask_question_screen.dart';

class ForumFeedScreen extends StatelessWidget {
  const ForumFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ForumProvider>();
    final posts = provider.filteredPosts;

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
                  onChanged: (val) => provider.setSearchQuery(val),
                  decoration: InputDecoration(
                    hintText: 'Rechercher une question...',
                    hintStyle:
                        TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    prefixIcon:
                        const Icon(Icons.search, size: 20, color: Colors.grey),
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

          // Questions List
          Expanded(
            child: posts.isEmpty
                ? Center(
                    child: Text(
                      'Aucune question trouvée',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 80),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      return PostCard(post: posts[index]);
                    },
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
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AskQuestionScreen(),
            ),
          );
        },
      ),
    );
  }
}
