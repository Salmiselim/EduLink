import 'package:flutter/material.dart';
import '../features/marketplace/models/marketplace_models.dart';
import '../features/marketplace/routes/marketplace_routes.dart';
import '../features/forum/models/post.dart';
import '../services/forum_marketplace_bridge.dart';
import '../features/forum/widgets/forum_ui.dart';

/// Liaison L7 : feuille « Trouver une ressource ou un tuteur » ouverte depuis
/// une question. Propose des offres de la Marketplace selon le cours et les tags.
Future<void> showResourceSuggestionsSheet(BuildContext context, Post post) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SuggestionsSheet(post: post),
  );
}

class _SuggestionsSheet extends StatelessWidget {
  final Post post;

  const _SuggestionsSheet({required this.post});

  @override
  Widget build(BuildContext context) {
    final offers = const ForumMarketplaceBridge()
        .suggestFor(courseName: post.courseName, tags: post.tags);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ressources et tuteurs suggérés',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: ForumColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Selon « ${post.courseName} » et les tags de votre question.',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: ForumColors.muted,
                ),
              ),
              const SizedBox(height: 12),
              if (offers.isEmpty)
                const ForumEmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'Aucune offre correspondante',
                  subtitle:
                      "Aucune ressource ni aucun cours particulier ne correspond pour l'instant.",
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: offers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _OfferTile(offer: offers[index]);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferTile extends StatelessWidget {
  final Offer offer;

  const _OfferTile({required this.offer});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: forumCardDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final navigator = Navigator.of(context);
            navigator.pop();
            navigator.pushNamed(
              MarketplaceRoutes.offerDetail,
              arguments: OfferDetailArgs(offerId: offer.id),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ForumPill(
                      label: offer.type.label,
                      color: ForumColors.primary,
                      background: ForumColors.infoBg,
                      icon: Icons.storefront_outlined,
                    ),
                    const Spacer(),
                    Text(
                      offer.formattedPrice,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: ForumColors.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  offer.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: ForumColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  offer.ratingCount > 0
                      ? '${offer.sellerName} · ${offer.ratingAvg.toStringAsFixed(1)} ★ (${offer.ratingCount})'
                      : offer.sellerName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ForumColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
