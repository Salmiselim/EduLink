import 'package:flutter/material.dart';
import '../models/marketplace_models.dart';

/// Carte réutilisable résumant une [Offer] dans la liste principale du catalogue
/// ou dans le carrousel horizontal de recommandations lorsque [compact] vaut `true`.
/// S'appuie sur un couple [Card] + [InkWell] pour gérer le découpage (`Clip.antiAlias`)
/// et l'effet d'onde tactile à l'ouverture du détail ou au clic sur le bouton favori.
class OfferCard extends StatelessWidget {
  final Offer offer;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  /// Réduit l'espacement interne et masque le bandeau de cours lié pour tenir dans le carrousel.
  final bool compact;

  const OfferCard({
    super.key,
    required this.offer,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteToggle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isTeacher = offer.sellerRole == SellerRole.teacher;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      // Zone cliquable principale déclenchant la navigation vers le détail de l'offre
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête : badges de catégorie et d'origine du vendeur dans un Wrap adaptatif + icône favori
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _TypeBadge(type: offer.type),
                        _SellerOriginBadge(isTeacher: isTeacher),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Zone tactile indépendante pour basculer le favori sans ouvrir la fiche détail
                  InkWell(
                    onTap: onFavoriteToggle,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 20,
                        color: isFavorite
                            ? const Color(0xFFEF4444)
                            : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Titre de l'offre limité à deux lignes avec troncature par ellipse
              Text(
                offer.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 14.5 : 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),

              // Puces de métadonnées dynamiques (matière/niveau, modalité Jitsi ou ville, état et stock)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _MetaChip(
                    icon: Icons.school_outlined,
                    label: '${offer.subject} · ${offer.level}',
                    bgColor: const Color(0xFFF1F5F9),
                    textColor: const Color(0xFF334155),
                  ),
                  if (offer.mode != null)
                    _MetaChip(
                      icon: offer.mode == DeliveryMode.online
                          ? Icons.videocam_outlined
                          : Icons.place_outlined,
                      label: offer.mode == DeliveryMode.online
                          ? 'En ligne (Jitsi)'
                          : offer.location?.city ?? 'Présentiel',
                      bgColor: const Color(0xFFEEF2FF),
                      textColor: const Color(0xFF4338CA),
                    ),
                  if (offer.type == OfferType.resourcePhysical &&
                      offer.condition != null)
                    _MetaChip(
                      icon: Icons.inventory_2_outlined,
                      label:
                          '${offer.condition!.label} (${offer.quantity ?? 0} disp.)',
                      bgColor: const Color(0xFFFEF3C7),
                      textColor: const Color(0xFFB45309),
                    ),
                ],
              ),

              // Bandeau indiquant le cours académique rattaché (affiché uniquement hors mode compact)
              if (!compact && offer.courseTitle != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.link_rounded,
                        size: 14,
                        color: Color(0xFF15803D),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Cours lié : ${offer.courseTitle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Pied de carte : avatar initiales du vendeur, note moyenne sur 5 et étiquette de tarif en TND
              Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: isTeacher
                        ? const Color(0xFFDBEAFE)
                        : const Color(0xFFF3E8FF),
                    child: Text(
                      offer.sellerAvatar,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isTeacher
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF6D28D9),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer.sellerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                offer.ratingCount > 0
                                    ? '${offer.ratingAvg.toStringAsFixed(1)} (${offer.ratingCount})${!compact ? ' · ${offer.salesCount} ventes' : ''}'
                                    : 'Nouveau',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Badge de prix en TND ou Gratuit
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: offer.isFree
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      offer.formattedPrice,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: offer.isFree
                            ? const Color(0xFF15803D)
                            : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Badge coloré affichant l'icône et l'intitulé court correspondant à [OfferType].
class _TypeBadge extends StatelessWidget {
  final OfferType type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: type.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 13, color: type.color),
          const SizedBox(width: 4),
          Text(
            type.shortLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: type.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge signalant le statut académique du vendeur (« Enseignant vérifié » ou « Offre étudiant »).
class _SellerOriginBadge extends StatelessWidget {
  final bool isTeacher;

  const _SellerOriginBadge({required this.isTeacher});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isTeacher ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isTeacher ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isTeacher ? Icons.verified_rounded : Icons.person_outline_rounded,
            size: 13,
            color: isTeacher
                ? const Color(0xFF2563EB)
                : const Color(0xFF64748B),
          ),
          const SizedBox(width: 4),
          Text(
            isTeacher ? 'Enseignant vérifié' : 'Offre étudiant',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isTeacher
                  ? const Color(0xFF1D4ED8)
                  : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}

/// Puce générique associant une icône et un court libellé descriptif.
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color textColor;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
