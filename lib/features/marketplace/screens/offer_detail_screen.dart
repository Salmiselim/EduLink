// Bibliothèque Material Design de Flutter : fournit Scaffold, AppBar, ListView, Wrap,
// ChoiceChip, CircleAvatar, AlertDialog, RadioGroup, RadioListTile, Form, TextFormField,
// SafeArea et FilledButton.icon.
import 'package:flutter/material.dart';

// Liaisons internes avec le contrôleur Singleton, les modèles et la table des routes nommées :
import '../data/marketplace_mock_data.dart';
import '../models/marketplace_models.dart';
import '../routes/marketplace_routes.dart';

// ============================================================================
// ROUTE POUSSÉE : DÉTAIL D'UNE OFFRE (OfferDetailScreen)
// Route nommée : `MarketplaceRoutes.offerDetail` (`/marketplace/offer-detail`)
// Reçoit un argument typé `OfferDetailArgs(offerId: ...)` via `MarketplaceRoutes.onGenerateRoute`.
//
// Cycle de vie & liaisons techniques :
// 1. Dans `initState()`, `WidgetsBinding.instance.addPostFrameCallback` attend la fin du 1er rendu
//    pour appeler `_controller.incrementViewCount(widget.offerId)` (`GET /offers/:id`) sans provoquer
//    d'erreur `setState() or markNeedsBuild() called during build`.
// 2. `ChoiceChip` permet à l'étudiant de présélectionner un créneau libre (`_highlightedSlot`),
//    qui est ensuite transmis dans `OrderCheckoutArgs(offer: offer, preselectedSlot: _highlightedSlot)`
//    lors du `Navigator.pushNamed(context, MarketplaceRoutes.orderCheckout, ...)`.
// 3. `AlertDialog` + `StatefulBuilder` + `RadioGroup<String>` + `Form` gèrent le signalement
//    (`POST /reports`) avec masquage automatique dès 3 signalements.
// 4. Règle 5 : si `isOwnOffer` (`offer.sellerId == currentUserId`), le `FilledButton.icon`
//    en bas de l'écran reçoit `onPressed: null`, ce qui le désactive visuellement et techniquement.
// ============================================================================

class OfferDetailScreen extends StatefulWidget {
  final String offerId;

  const OfferDetailScreen({
    super.key,
    required this.offerId,
  });

  @override
  State<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends State<OfferDetailScreen> {
  final MarketplaceController _controller = MarketplaceController.instance;

  /// Créneau éventuellement présélectionné par l'utilisateur avant d'appuyer sur « Réserver »
  AvailabilitySlot? _highlightedSlot;

  @override
  void initState() {
    super.initState();
    // Incrémente automatiquement le compteur de vues (`viewsCount`) à l'ouverture
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.incrementViewCount(widget.offerId);
    });
  }

  /// Affiche la boîte de dialogue de signalement d'une offre (`POST /reports`, Page 8 Métier 1)
  /// Inclut un contrôle de saisie si l'utilisateur sélectionne « Autre motif ».
  void _showReportDialog(Offer offer) {
    String selectedReason = 'Contenu inapproprié ou trompeur';
    final reasons = [
      'Contenu inapproprié ou trompeur',
      'Violation de droits d\'auteur / plagiat',
      'Prix abusif ou arnaque suspectée',
      'Offre hors sujet académique',
      'Autre motif (préciser)',
    ];
    final formKey = GlobalKey<FormState>();
    final detailsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.flag_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Signaler cette offre',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Une offre est masquée automatiquement à partir de 3 signalements (actuellement : ${offer.reportsCount}/3).',
                    style:
                        TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  RadioGroup<String>(
                    groupValue: selectedReason,
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedReason = val);
                      }
                    },
                    child: Column(
                      children: reasons
                          .map(
                            (reason) => RadioListTile<String>(
                              value: reason,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                reason,
                                style: const TextStyle(fontSize: 13.5),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  if (selectedReason == 'Autre motif (préciser)') ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: detailsCtrl,
                      maxLength: 150,
                      validator: (val) {
                        final text = val?.trim() ?? '';
                        if (text.length < 6) {
                          return 'Veuillez préciser le motif (min. 6 caractères).';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Précisez le motif du signalement *',
                        hintText: 'Ex: Lien invalide ou description erronée...',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? true)) {
                  return;
                }
                final reasonToSend = selectedReason == 'Autre motif (préciser)'
                    ? detailsCtrl.text.trim()
                    : selectedReason;
                final autoHidden =
                    _controller.reportOffer(offer.id, reasonToSend);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      autoHidden
                          ? 'Signalement enregistré (3/3) : cette offre a été masquée automatiquement.'
                          : 'Signalement envoyé (POST /reports). Merci pour votre vigilance.',
                    ),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              child: const Text('Envoyer le signalement'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final offer = _controller.allOffers.firstWhere(
          (o) => o.id == widget.offerId,
          orElse: () => _controller.allOffers.first,
        );
        final isFav = _controller.isFavorite(offer.id);
        final isOwnOffer = offer.sellerId == _controller.currentUserId;
        final isTeacher = offer.sellerRole == SellerRole.teacher;
        final slots = _controller.getSlotsForOffer(offer.id);
        final reviews = _controller.getReviewsForOffer(offer.id);

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Text(
              'Détail de l\'offre',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            actions: [
              // Bouton Favori (`PUT | DELETE /favorites`)
              IconButton(
                tooltip: isFav ? 'Retirer des favoris' : 'Ajouter aux favoris',
                onPressed: () => _controller.toggleFavorite(offer.id),
                icon: Icon(
                  isFav
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFav ? const Color(0xFFEF4444) : null,
                ),
              ),
              // Bouton Signalement (`POST /reports`)
              IconButton(
                tooltip: 'Signaler l\'offre (POST /reports)',
                onPressed: () => _showReportDialog(offer),
                icon: const Icon(Icons.flag_outlined),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. En-tête visuel : Badges (Type + Rôle Vendeur) + Titre + Compteurs (Avis, Vues, Commandes)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      offer.type.color.withValues(alpha: 0.14),
                      Colors.white,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: offer.type.color.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: offer.type.color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                offer.type.icon,
                                size: 15,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                offer.type.label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isTeacher
                                ? const Color(0xFFDBEAFE)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isTeacher
                                  ? const Color(0xFF93C5FD)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isTeacher
                                    ? Icons.verified_rounded
                                    : Icons.school_outlined,
                                size: 14,
                                color: isTeacher
                                    ? const Color(0xFF1D4ED8)
                                    : const Color(0xFF475569),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                offer.sellerRole.badgeLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isTeacher
                                      ? const Color(0xFF1D4ED8)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (offer.status != OfferStatus.published)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: offer.status.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Statut : ${offer.status.label}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: offer.status.color,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      offer.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _StatPill(
                          icon: Icons.star_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          label: offer.ratingCount > 0
                              ? '${offer.ratingAvg.toStringAsFixed(2)} (${offer.ratingCount} avis)'
                              : 'Aucun avis',
                        ),
                        _StatPill(
                          icon: Icons.visibility_outlined,
                          iconColor: const Color(0xFF64748B),
                          label: '${offer.viewsCount} vues',
                        ),
                        _StatPill(
                          icon: Icons.shopping_bag_outlined,
                          iconColor: const Color(0xFF16A34A),
                          label: '${offer.salesCount} commandes',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Liaison L6 : affiche le cours rattaché (`offers.courseId`)
              if (offer.courseTitle != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: Color(0xFF15803D),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ressource rattachée à un cours (Liaison L6)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF166534),
                              ),
                            ),
                            Text(
                              offer.courseTitle!,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF14532D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 3. Description et caractéristiques techniques selon le type d'offre
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Description & Particularités',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      offer.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF334155),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: 'Matière & Niveau',
                      value: '${offer.subject} · Niveau ${offer.level}',
                    ),
                    if (offer.type == OfferType.resourceDigital) ...[
                      _DetailRow(
                        label: 'Format du fichier',
                        value: offer.fileSizeLabel ?? 'Document PDF privé',
                      ),
                      _DetailRow(
                        label: 'Accès au téléchargement',
                        value: offer.isFree
                            ? 'Immédiat (Offre gratuite)'
                            : 'Débloqué après acceptation de la commande',
                      ),
                    ],
                    if (offer.type == OfferType.resourcePhysical) ...[
                      _DetailRow(
                        label: 'État de la ressource',
                        value: offer.condition?.label ?? 'Bon état',
                      ),
                      _DetailRow(
                        label: 'Quantité en stock',
                        value: '${offer.quantity ?? 0} exemplaire(s)',
                      ),
                    ],
                    if (offer.mode != null)
                      _DetailRow(
                        label: 'Modalité',
                        value: offer.mode!.label,
                      ),
                    if (offer.location != null)
                      _DetailRow(
                        label: 'Lieu (OpenStreetMap Nominatim)',
                        value:
                            '${offer.location!.address} (${offer.location!.city})',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Créneaux horaires disponibles (`availabilities`) pour un cours particulier
              if (offer.type == OfferType.privateLesson) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.event_available_rounded,
                            color: Color(0xFF7C3AED),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Créneaux de disponibilité (1 h)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Text(
                            '${slots.where((s) => !s.isBooked).length} libre(s)',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (slots.isEmpty)
                        const Text(
                          'Aucun créneau renseigné.',
                          style: TextStyle(color: Colors.grey),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: slots.map((slot) {
                            final isSelected = _highlightedSlot?.id == slot.id;
                            return ChoiceChip(
                              selected: isSelected,
                              onSelected: slot.isBooked
                                  ? null
                                  : (_) {
                                      setState(() => _highlightedSlot = slot);
                                    },
                              label: Text(
                                '${slot.date} · ${slot.startTime}-${slot.endTime}${slot.isBooked ? " (Réservé)" : ""}',
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 5. Profil public du vendeur & ses badges M5 (Liaison L9)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'À propos du vendeur',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: isTeacher
                              ? const Color(0xFFDBEAFE)
                              : const Color(0xFFF3E8FF),
                          child: Text(
                            offer.sellerAvatar,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isTeacher
                                  ? const Color(0xFF1D4ED8)
                                  : const Color(0xFF6D28D9),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                offer.sellerName,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                offer.sellerSubtitle,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (offer.sellerBadges.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: offer.sellerBadges.map((b) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.workspace_premium_rounded,
                                  size: 14,
                                  color: Color(0xFFB45309),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Badge $b',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 6. Liste des avis vérifiés laissés par les acheteurs (`reviews`)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Avis vérifiés (commandes terminées)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFF59E0B),
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          offer.ratingCount > 0
                              ? '${offer.ratingAvg.toStringAsFixed(1)} / 5'
                              : '-',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (reviews.isEmpty)
                      Text(
                        'Aucun avis pour le moment sur cette offre.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      )
                    else
                      ...reviews.map((rev) => _ReviewTile(review: rev)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),

          // Barre d'action inférieure : affiche le prix et pousse la route nommée `MarketplaceRoutes.orderCheckout`
          // Règle 5 (Page 2) : Désactivée si `isOwnOffer` (on ne peut ni acheter ni réserver sa propre offre)
          bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.type == OfferType.privateLesson
                            ? 'Tarif horaire'
                            : 'Prix de l\'offre',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        offer.formattedPrice,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: offer.isFree
                              ? const Color(0xFF15803D)
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: isOwnOffer ||
                                offer.status == OfferStatus.soldOut
                            ? null
                            : () {
                                Navigator.pushNamed(
                                  context,
                                  MarketplaceRoutes.orderCheckout,
                                  arguments: OrderCheckoutArgs(
                                    offer: offer,
                                    preselectedSlot: _highlightedSlot,
                                  ),
                                );
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: Icon(
                          isOwnOffer
                              ? Icons.info_outline_rounded
                              : offer.type == OfferType.privateLesson
                                  ? Icons.calendar_month_rounded
                                  : Icons.shopping_cart_checkout_rounded,
                        ),
                        label: Text(
                          isOwnOffer
                              ? 'Votre propre offre (Règle 5)'
                              : offer.status == OfferStatus.soldOut
                                  ? 'Rupture de stock'
                                  : offer.type == OfferType.privateLesson
                                      ? 'Réserver un créneau'
                                      : offer.isFree
                                          ? 'Télécharger gratuitement'
                                          : 'Commander cette ressource',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Pilule de statistique (Note moyenne ★, nombre de vues, nombre de ventes)
class _StatPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _StatPill({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne clé/valeur affichant une caractéristique technique de l'offre
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte affichant un avis vérifié d'un acheteur (`OfferReview`)
class _ReviewTile extends StatelessWidget {
  final OfferReview review;

  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                review.buyerName,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '· ${review.buyerRoleLabel}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 14,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            review.comment,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF334155),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
