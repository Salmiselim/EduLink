import 'package:flutter/material.dart';
import '../models/marketplace_models.dart';

// ============================================================================
// COMPOSANT RÉUTILISABLE : CARTE D'OFFRE (OfferCard)
// Utilisée dans le catalogue principal et dans le carrousel des recommandations (L6).
// Affiche :
// - Le type d'offre (Numérique PDF, Physique, Cours 1h)
// - Le badge obligatoire d'origine du vendeur (« Offre étudiant » / « Enseignant vérifié », Règle 5)
// - Le bouton Favori ♥ (PUT | DELETE /favorites)
// - Le titre, la matière, le niveau, le mode (Jitsi / Ville) et l'état/stock
// - Le cours rattaché (Liaison L6)
// - L'avatar et le nom du vendeur, la note moyenne ★ et le prix en TND (ou Gratuit)
// ============================================================================

class OfferCard extends StatelessWidget {
  final Offer offer;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final bool compact; // Mode compact pour le carrousel horizontal des recommandations

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
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Ligne du haut : Badge Type d'offre + Badge Origine du vendeur (Règle 5) + Bouton Favori
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

              // 2. Titre de l'offre
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

              // 3. Puces de métadonnées : Matière · Niveau · Mode (En ligne / Ville) · État & Stock
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

              // 4. Bandeau Liaison L6 : affiche le cours rattaché s'il existe
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

              // 5. Pied de carte : Infos Vendeur + Note moyenne ★ + Prix en TND (ou Gratuit)
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

/// Badge coloré indiquant le type de l'offre (`resource_digital`, `resource_physical`, `private_lesson`)
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

/// Badge indiquant l'origine du vendeur : « Enseignant vérifié » ou « Offre étudiant » (Règle 5, Page 2)
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

/// Petite étiquette d'information (Matière/Niveau, Mode Jitsi/Ville, État/Stock)
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
