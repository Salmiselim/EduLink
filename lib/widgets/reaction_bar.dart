import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reaction.dart';
import '../providers/forum_provider.dart';
import 'forum_ui.dart';

/// Barre des réactions emoji (👍 J'aime, ✅ Utile, 💡 Instructif, 👏 Bravo,
/// 🎯 Pertinent) d'une question ou d'une réponse.
/// Une seule réaction par utilisateur : toucher la même la retire, une autre la remplace.
class ReactionBar extends StatelessWidget {
  final ReactionTarget target;
  final String targetId;

  const ReactionBar({super.key, required this.target, required this.targetId});

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
              border: Border.all(
                color: active ? ForumColors.primary : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(type.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  count > 0 ? '${type.label} · $count' : type.label,
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
