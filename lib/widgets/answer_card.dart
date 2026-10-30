import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/answer.dart';
import '../providers/forum_provider.dart';
import '../utils/time_format.dart';
import 'forum_ui.dart';
import 'role_badge.dart';

/// Carte représentant une réponse (`Answer`) au sein de `QuestionDetailScreen`.
/// Permet à tout utilisateur de voter positivement et à un enseignant de marquer
/// la réponse d'un étudiant comme vérifiée.
class AnswerCard extends StatelessWidget {
  final Answer answer;

  const AnswerCard({super.key, required this.answer});

  @override
  Widget build(BuildContext context) {
    // Écoute `ForumProvider` pour refléter l'état du rôle courant et des votes.
    final provider = context.watch<ForumProvider>();
    // L'action de vérification est réservée aux enseignants sur les réponses rédigées par des étudiants.
    final canVerify = provider.isTeacher && !answer.isTeacher;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        // Met en valeur la bordure en vert lorsque la réponse porte la mention vérifiée.
        decoration: forumCardDecoration(
          borderColor: answer.isTeacherVerified
              ? ForumColors.success
              : ForumColors.border,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête : avatar, identité de l'auteur avec badge de rôle et bouton de vote positif.
            Row(
              children: [
                ForumAvatar(
                  name: answer.authorName,
                  isTeacher: answer.isTeacher,
                  radius: 15,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              answer.authorName,
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
                          RoleBadge(role: answer.authorRole),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatTimeAgo(answer.createdAt),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: ForumColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Bouton interactif incrémentant ou retirant le vote positif via `ForumProvider`.
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => provider.toggleVoteAnswer(answer.id),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: answer.isUpvoted
                          ? ForumColors.infoBg
                          : ForumColors.neutralBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          answer.isUpvoted
                              ? Icons.thumb_up_rounded
                              : Icons.thumb_up_alt_outlined,
                          size: 14,
                          color: answer.isUpvoted
                              ? ForumColors.primary
                              : ForumColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${answer.votesCount}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: answer.isUpvoted
                                ? ForumColors.primary
                                : ForumColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Contenu textuel de la réponse.
            Text(
              answer.body,
              style: const TextStyle(
                fontSize: 13.5,
                color: ForumColors.textSecondary,
                height: 1.5,
              ),
            ),

            // Pied de carte conditionnel affichant le badge de validation et le bouton enseignant.
            if (answer.isTeacherVerified || canVerify) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (answer.isTeacherVerified)
                    const ForumPill(
                      label: 'Réponse vérifiée',
                      color: ForumColors.success,
                      background: ForumColors.successBg,
                      icon: Icons.verified_rounded,
                    ),
                  const Spacer(),
                  if (canVerify)
                    TextButton.icon(
                      onPressed: () => provider.toggleVerifyAnswer(answer.id),
                      style: TextButton.styleFrom(
                        foregroundColor: ForumColors.primary,
                      ),
                      icon: Icon(
                        answer.isTeacherVerified
                            ? Icons.remove_done_rounded
                            : Icons.verified_outlined,
                        size: 16,
                      ),
                      label: Text(
                        answer.isTeacherVerified
                            ? 'Retirer la vérification'
                            : 'Marquer comme vérifiée',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
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
