import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/answer.dart';
import '../providers/forum_provider.dart';
import '../utils/time_format.dart';
import 'role_badge.dart';

class AnswerCard extends StatelessWidget {
  final Answer answer;

  const AnswerCard({super.key, required this.answer});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ForumProvider>();
    // Seul un enseignant peut vérifier la réponse d'un autre utilisateur.
    final canVerify = provider.isTeacher && !answer.isTeacher;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: answer.isTeacherVerified
              ? Colors.green.shade300
              : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author row
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: answer.isTeacher
                      ? Colors.amber.shade100
                      : Colors.indigo.shade50,
                  child: Text(
                    answer.authorName.isNotEmpty ? answer.authorName[0] : 'U',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: answer.isTeacher
                          ? Colors.amber.shade900
                          : Colors.indigo.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              answer.authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          RoleBadge(role: answer.authorRole),
                        ],
                      ),
                      Text(
                        formatTimeAgo(answer.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Simple Upvote Button
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => provider.toggleVoteAnswer(answer.id),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: answer.isUpvoted
                          ? Colors.indigo.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          answer.isUpvoted
                              ? Icons.thumb_up
                              : Icons.thumb_up_alt_outlined,
                          size: 14,
                          color: answer.isUpvoted
                              ? Colors.indigo
                              : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${answer.votesCount}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: answer.isUpvoted
                                ? Colors.indigo
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Answer text
            Text(
              answer.body,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF334155),
                height: 1.4,
              ),
            ),

            // Réponse vérifiée + action enseignant
            if (answer.isTeacherVerified || canVerify) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (answer.isTeacherVerified)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified,
                              size: 14, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'Réponse vérifiée',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  if (canVerify)
                    TextButton.icon(
                      onPressed: () =>
                          provider.toggleVerifyAnswer(answer.id),
                      icon: Icon(
                        answer.isTeacherVerified
                            ? Icons.remove_done_outlined
                            : Icons.verified_outlined,
                        size: 16,
                      ),
                      label: Text(
                        answer.isTeacherVerified
                            ? 'Retirer la vérification'
                            : 'Marquer comme vérifiée',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
