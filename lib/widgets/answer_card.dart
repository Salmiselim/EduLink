import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/forum/models/answer.dart';
import '../features/forum/models/post.dart';
import '../models/reaction.dart';
import '../providers/forum_provider.dart';
import '../features/forum/utils/time_format.dart';
import 'code_block.dart';
import '../features/forum/widgets/forum_ui.dart';
import 'rating_bar.dart';
import 'reaction_bar.dart';
import 'reply_edit_dialog.dart';
import 'role_badge.dart';

/// Carte d'une réponse : texte, extrait de code exécutable, réactions et actions
/// (accepter pour l'auteur de la question, vérifier pour l'enseignant,
/// modifier/supprimer pour l'auteur de la réponse).
class AnswerCard extends StatelessWidget {
  final Answer answer;
  final Post post;

  const AnswerCard({super.key, required this.answer, required this.post});

  Future<void> _edit(BuildContext context) async {
    final provider = context.read<ForumProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await showReplyEditDialog(context, answer: answer);
    if (result == null) return;

    final ok = provider.updateAnswer(
      answer.id,
      body: result.body,
      codeSnippet: result.codeSnippet,
      codeLanguage: result.codeLanguage,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? 'Réponse modifiée' : 'Modification impossible'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final provider = context.read<ForumProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmForumDelete(
      context,
      title: 'Supprimer la réponse ?',
      message: 'Cette action est définitive.',
    );
    if (!confirmed) return;

    final ok = provider.deleteAnswer(answer.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? 'Réponse supprimée' : 'Suppression impossible'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ForumProvider>();
    final isAccepted = post.acceptedReplyId == answer.id;
    // L'auteur d'une question ne peut pas accepter sa propre réponse.
    final canAccept =
        provider.canAcceptAnswer(post) && answer.authorId != post.authorId;
    // Seul un enseignant peut vérifier la réponse d'un autre utilisateur.
    final canVerify = provider.isTeacher && !answer.isTeacher;
    final canModify = provider.canModifyAnswer(answer);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: forumCardDecoration(
          borderColor: isAccepted ? ForumColors.success : ForumColors.border,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Auteur, horodatage et menu
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
                        answer.isEdited
                            ? '${formatTimeAgo(answer.createdAt)} · modifiée'
                            : formatTimeAgo(answer.createdAt),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: ForumColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canModify)
                  PopupMenuButton<String>(
                    tooltip: 'Options de la réponse',
                    icon: const Icon(Icons.more_vert_rounded,
                        size: 20, color: ForumColors.muted),
                    onSelected: (value) {
                      if (value == 'edit') _edit(context);
                      if (value == 'delete') _delete(context);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Modifier')),
                      PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                    ],
                  ),
              ],
            ),

            // États : acceptée / vérifiée
            if (isAccepted || answer.isTeacherVerified) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (isAccepted)
                    const ForumPill(
                      label: 'Réponse acceptée',
                      color: ForumColors.success,
                      background: ForumColors.successBg,
                      icon: Icons.check_circle_rounded,
                    ),
                  if (answer.isTeacherVerified)
                    const ForumPill(
                      label: 'Réponse vérifiée',
                      color: ForumColors.primary,
                      background: ForumColors.infoBg,
                      icon: Icons.verified_rounded,
                    ),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // Texte de la réponse
            Text(
              answer.body,
              style: const TextStyle(
                fontSize: 13.5,
                color: ForumColors.textSecondary,
                height: 1.5,
              ),
            ),

            // Extrait de code (exécutable)
            if (answer.hasCode) ...[
              const SizedBox(height: 10),
              ForumCodeBlock(
                code: answer.codeSnippet!,
                language: answer.codeLanguage,
              ),
            ],

            const SizedBox(height: 10),
            ReactionBar(target: ReactionTarget.reply, targetId: answer.id),
            const SizedBox(height: 6),
            RatingBar(target: ReactionTarget.reply, targetId: answer.id),

            // Actions : accepter (auteur de la question), vérifier (enseignant)
            if (canAccept || canVerify) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                children: [
                  if (canAccept)
                    TextButton.icon(
                      onPressed: () =>
                          provider.toggleAcceptAnswer(post.id, answer.id),
                      style: TextButton.styleFrom(
                        foregroundColor: ForumColors.success,
                      ),
                      icon: Icon(
                        isAccepted
                            ? Icons.cancel_outlined
                            : Icons.check_circle_outline_rounded,
                        size: 16,
                      ),
                      label: Text(
                        isAccepted
                            ? "Retirer l'acceptation"
                            : 'Accepter cette réponse',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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
