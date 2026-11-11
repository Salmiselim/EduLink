import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/forum/models/post.dart';
import '../models/reaction.dart';
import '../providers/forum_provider.dart';
import '../features/forum/routes/app_routes.dart';
import '../features/forum/utils/time_format.dart';
import '../features/forum/widgets/forum_ui.dart';
import 'role_badge.dart';

class PostCard extends StatelessWidget {
  final Post post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ForumProvider>();
    final reactions = provider.reactionCount(ReactionTarget.post, post.id);
    final ratings = provider.ratingStats(ReactionTarget.post, post.id);

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
                              post.isEdited
                                  ? '${formatTimeAgo(post.createdAt)} · modifiée'
                                  : formatTimeAgo(post.createdAt),
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

                  // Cours concerné + état
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ForumPill(
                        label: post.courseName,
                        color: ForumColors.primary,
                        background: ForumColors.infoBg,
                        icon: Icons.sell_outlined,
                      ),
                      if (post.isResolved)
                        const ForumPill(
                          label: 'Résolue',
                          color: ForumColors.success,
                          background: ForumColors.successBg,
                          icon: Icons.check_circle_rounded,
                        ),
                    ],
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

                  // Tags (un toucher filtre le fil)
                  if (post.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: post.tags
                          .map((tag) => ForumTag(
                                label: tag,
                                onTap: () => provider.setTagFilter(tag),
                              ))
                          .toList(),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Réponses, code, réactions
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
                      if (post.hasCode) ...[
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.code_rounded,
                          size: 15,
                          color: ForumColors.muted,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Code',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ForumColors.muted,
                          ),
                        ),
                      ],
                      if (reactions > 0) ...[
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.favorite_border_rounded,
                          size: 15,
                          color: ForumColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$reactions',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ForumColors.muted,
                          ),
                        ),
                      ],
                      if (ratings.count > 0) ...[
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: ForumColors.warning,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${ratings.average.toStringAsFixed(1)} (${ratings.count})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ForumColors.muted,
                          ),
                        ),
                      ],
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
