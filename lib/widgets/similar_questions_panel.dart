import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../features/forum/widgets/forum_ui.dart';
import '../services/stack_overflow_service.dart';

/// Encart « Questions similaires sur Stack Overflow » du formulaire de question.
/// Affiche les résultats de l'API Stack Exchange pendant la saisie du titre,
/// pour éviter les doublons et orienter l'étudiant vers une réponse existante.
class SimilarQuestionsPanel extends StatelessWidget {
  final bool loading;
  final List<StackQuestion> questions;
  final String? error;

  const SimilarQuestionsPanel({
    super.key,
    required this.loading,
    required this.questions,
    this.error,
  });

  Future<void> _open(BuildContext context, StackQuestion question) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(question.link),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (opened) return;
    // Pas de navigateur disponible : on copie le lien à la place.
    await Clipboard.setData(ClipboardData(text: question.link));
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Lien copié dans le presse-papiers'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ForumColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.travel_explore_rounded,
                  size: 18, color: ForumColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Questions similaires sur Stack Overflow',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: ForumColors.text,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                error!,
                style: const TextStyle(fontSize: 12.5, color: ForumColors.muted),
              ),
            ),
          for (final question in questions)
            InkWell(
              onTap: () => _open(context, question),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        question.isAnswered
                            ? Icons.check_circle_rounded
                            : Icons.help_outline_rounded,
                        size: 16,
                        color: question.isAnswered
                            ? ForumColors.success
                            : ForumColors.muted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            question.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ForumColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${question.answerCount} réponse'
                            '${question.answerCount > 1 ? 's' : ''}'
                            ' · score ${question.score}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: ForumColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.open_in_new_rounded,
                        size: 15, color: ForumColors.muted),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          const Text(
            'Source : Stack Overflow (API Stack Exchange). Contenu sous licence CC BY-SA.',
            style: TextStyle(fontSize: 10.5, color: ForumColors.muted),
          ),
        ],
      ),
    );
  }
}
