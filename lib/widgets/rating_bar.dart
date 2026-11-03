import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reaction.dart';
import '../providers/forum_provider.dart';
import 'forum_ui.dart';

/// Notation d'une question ou d'une réponse : 5 étoiles à toucher (toucher la
/// même étoile retire la note) et la moyenne avec le nombre d'avis.
/// On ne peut pas noter son propre contenu : les étoiles affichent alors la moyenne.
class RatingBar extends StatelessWidget {
  final ReactionTarget target;
  final String targetId;

  const RatingBar({super.key, required this.target, required this.targetId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ForumProvider>();
    final stats = provider.ratingStats(target, targetId);
    final mine = provider.myRating(target, targetId);
    final canRate = provider.canRate(target, targetId);
    final filled = canRate ? (mine ?? 0) : stats.average.round();

    final String summary;
    if (stats.count == 0) {
      summary = canRate ? 'Soyez le premier à noter' : 'Pas encore de note';
    } else {
      summary = '${stats.average.toStringAsFixed(1)} · ${stats.count} avis';
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final value = index + 1;
            return Tooltip(
              message: canRate
                  ? 'Noter $value sur 5'
                  : 'Vous ne pouvez pas noter votre propre contenu',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: canRate ? () => provider.rate(target, targetId, value) : null,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    value <= filled
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 22,
                    color: value <= filled
                        ? ForumColors.warning
                        : ForumColors.muted,
                  ),
                ),
              ),
            );
          }),
        ),
        Text(
          summary,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: ForumColors.muted,
          ),
        ),
      ],
    );
  }
}
