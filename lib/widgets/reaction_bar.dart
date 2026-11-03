import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reaction.dart';
import '../providers/forum_provider.dart';
import 'forum_ui.dart';

/// Barre des 3 réactions (J'aime, Utile, Instructif) d'une question ou d'une réponse.
/// Une seule réaction par utilisateur : toucher la même la retire, une autre la remplace.
class ReactionBar extends StatelessWidget {
  final ReactionTarget target;
  final String targetId;

  const ReactionBar({super.key, required this.target, required this.targetId});

  IconData _icon(ReactionType type, bool active) {
    switch (type) {
      case ReactionType.like:
        return active
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded;
      case ReactionType.helpful:
        return active
            ? Icons.thumb_up_rounded
            : Icons.thumb_up_alt_outlined;
      case ReactionType.insightful:
        return active
            ? Icons.lightbulb_rounded
            : Icons.lightbulb_outline_rounded;
    }
  }

  String _label(ReactionType type) {
    switch (type) {
      case ReactionType.like:
        return "J'aime";
      case ReactionType.helpful:
        return 'Utile';
      case ReactionType.insightful:
        return 'Instructif';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ForumProvider>();
    final mine = provider.myReaction(target, targetId);

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: ReactionType.values.map((type) {
        final active = mine == type;
        final count = provider.reactionCount(target, targetId, type: type);
        final color = active ? ForumColors.primary : ForumColors.muted;

        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => provider.toggleReaction(target, targetId, type),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: active ? ForumColors.infoBg : ForumColors.neutralBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_icon(type, active), size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  count > 0 ? '${_label(type)} · $count' : _label(type),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
