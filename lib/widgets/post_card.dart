import 'package:flutter/material.dart';
import '../models/post.dart';
import '../routes/app_routes.dart';
import '../utils/time_format.dart';
import 'forum_ui.dart';
import 'role_badge.dart';

class PostCard extends StatelessWidget {
  final Post post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: forumCardDecoration(),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.pushNamed(
              context,
              ForumRoutes.forumQuestion,
              arguments: post.id,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Auteur + horodatage
                  Row(
                    children: [
                      ForumAvatar(name: post.authorName, isTeacher: post.isTeacher),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    post.authorName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: ForumColors.text,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                RoleBadge(role: post.authorRole),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatTimeAgo(post.createdAt),
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: ForumColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Cours concerné
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ForumPill(
                      label: post.courseName,
                      color: ForumColors.primary,
                      background: ForumColors.infoBg,
                      icon: Icons.sell_outlined,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Titre
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: ForumColors.text,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Aperçu du corps
                  Text(
                    post.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: ForumColors.textSecondary,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Nombre de réponses
                  Row(
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 15,
                        color: ForumColors.muted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${post.answersCount} réponse${post.answersCount > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ForumColors.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
