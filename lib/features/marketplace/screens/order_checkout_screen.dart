// Bibliothèque Material Design de Flutter : fournit Scaffold, AppBar, Form, GlobalKey<FormState>,
// TextFormField, ListTile, IconButton.outlined, SafeArea, FilledButton.icon et SnackBar.
import 'package:flutter/material.dart';

// Liaisons avec le contrôleur (`createOrder`), les modèles et la table des routes (`pushReplacementNamed`) :
import '../data/marketplace_mock_data.dart';
import '../models/marketplace_models.dart';
import '../routes/marketplace_routes.dart';

// ============================================================================
// ROUTE POUSSÉE : ÉCRAN DE COMMANDE OU DE RÉSERVATION (OrderCheckoutScreen)
// Route nommée : `MarketplaceRoutes.orderCheckout` (`/marketplace/order-checkout`)
// Reçoit `OrderCheckoutArgs(offer: ..., preselectedSlot: ...)` depuis `OfferDetailScreen`.
//
// Liaisons techniques et parcours utilisateur :
// 1. Adapte dynamiquement son interface selon `offer.type` :
//    - `privateLesson` : sélection d'un `AvailabilitySlot` libre via `ListTile` radio (les créneaux déjà
//      réservés `slot.isBooked` sont grisés, barrés et ont `onTap: null`).
//    - `resourcePhysical` : sélecteur de quantité borné `[1..maxStock]` via `IconButton.outlined`
//      et affichage du lieu de remise OpenStreetMap Nominatim.
//    - `resourceDigital` : récapitulatif du PDF privé Cloudinary (débloqué immédiatement si gratuit).
// 2. Valide le message initial `orders.note` (>= 10 caractères) via `_formKey.currentState!.validate()`.
// 3. Appelle `_controller.createOrder(...)` puis utilise `Navigator.pushReplacementNamed` vers
//    `MarketplaceRoutes.orderChat` afin de remplacer l'écran de paiement par le chat de suivi
//    (évite de recréer une commande en double si l'utilisateur appuie sur le bouton Retour).
// ============================================================================

class OrderCheckoutScreen extends StatefulWidget {
  final Offer offer;
  final AvailabilitySlot? preselectedSlot;

  const OrderCheckoutScreen({
    super.key,
    required this.offer,
    this.preselectedSlot,
  });

  @override
  State<OrderCheckoutScreen> createState() => _OrderCheckoutScreenState();
}

class _OrderCheckoutScreenState extends State<OrderCheckoutScreen> {
  final MarketplaceController _controller = MarketplaceController.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _noteController = TextEditingController();

  /// Quantité souhaitée (utilisée pour les ressources physiques)
  int _quantity = 1;

  /// Créneau de disponibilité sélectionné (utilisé pour les cours particuliers)
  AvailabilitySlot? _selectedSlot;

  /// Message d'erreur de validation si aucun créneau n'est sélectionné
  String? _slotValidationError;

  @override
  void initState() {
    super.initState();
    _selectedSlot = widget.preselectedSlot;
    // Si aucun créneau n'a été présélectionné sur l'écran précédent, on sélectionne le 1er créneau libre
    if (_selectedSlot == null && widget.offer.type == OfferType.privateLesson) {
      final freeSlots = _controller
          .getSlotsForOffer(widget.offer.id)
          .where((s) => !s.isBooked)
          .toList();
      if (freeSlots.isNotEmpty) {
        _selectedSlot = freeSlots.first;
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// Exécute tous les contrôles de saisie avant de créer la commande (`POST /orders`)
  void _confirmOrder() {
    bool isSlotValid = true;
    if (widget.offer.type == OfferType.privateLesson && _selectedSlot == null) {
      setState(() {
        _slotValidationError =
            'Sélection obligatoire : veuillez choisir un créneau horaire libre.';
      });
      isSlotValid = false;
    } else {
      setState(() => _slotValidationError = null);
    }

    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isSlotValid || !isFormValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFDC2626),
          content: Text(
            'Veuillez corriger les champs en erreur avant de confirmer la commande.',
          ),
        ),
      );
      return;
    }

    final createdOrder = _controller.createOrder(
      offer: widget.offer,
      quantity: _quantity,
      selectedSlot: _selectedSlot,
      note: _noteController.text.trim(),
    );

    // Navigation par route nommée vers le Chat lié à la commande créée
    Navigator.pushReplacementNamed(
      context,
      MarketplaceRoutes.orderChat,
      arguments: OrderChatArgs(orderId: createdOrder.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final slots = _controller.getSlotsForOffer(offer.id);
    final maxStock = (offer.quantity ?? 1).clamp(1, 20);
    final totalPrice = offer.price * _quantity;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          offer.type == OfferType.privateLesson
              ? 'Réserver un créneau'
              : 'Confirmer la commande',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Carte récapitulative de l'offre et du vendeur
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
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: offer.type.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(offer.type.icon, color: offer.type.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              offer.type.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: offer.type.color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              offer.title,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        offer.sellerRole == SellerRole.teacher
                            ? Icons.verified_rounded
                            : Icons.person_outline_rounded,
                        size: 16,
                        color: const Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${offer.sellerName} (${offer.sellerRole.badgeLabel})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        offer.formattedPrice,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2A. Cas d'un Cours particulier (`private_lesson`) : sélection d'un créneau libre
            if (offer.type == OfferType.privateLesson) ...[
              _SectionCard(
                title: '1. Choisir un créneau de disponibilité *',
                subtitle:
                    'Le créneau choisi sera verrouillé par une transaction Firestore pour éviter toute double réservation.',
                icon: Icons.calendar_month_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (slots.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Aucun créneau publié pour le moment.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ...slots.map((slot) {
                        final isSelected = _selectedSlot?.id == slot.id;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: slot.isBooked
                                ? const Color(0xFFF1F5F9)
                                : isSelected
                                    ? const Color(0xFFEFF6FF)
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: slot.isBooked
                                  ? Colors.grey.shade300
                                  : isSelected
                                      ? const Color(0xFF2563EB)
                                      : Colors.grey.shade300,
                              width: isSelected ? 1.8 : 1,
                            ),
                          ),
                          child: ListTile(
                            onTap: slot.isBooked
                                ? null
                                : () => setState(() {
                                      _selectedSlot = slot;
                                      _slotValidationError = null;
                                    }),
                            leading: Icon(
                              slot.isBooked
                                  ? Icons.lock_outline_rounded
                                  : isSelected
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                              color: slot.isBooked
                                  ? Colors.grey
                                  : const Color(0xFF2563EB),
                            ),
                            title: Text(
                              slot.date,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                decoration: slot.isBooked
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: slot.isBooked
                                    ? Colors.grey
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            subtitle: Text(
                              'Horaires : ${slot.startTime} – ${slot.endTime} (1 h)',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: slot.isBooked
                                    ? Colors.grey
                                    : const Color(0xFF475569),
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: slot.isBooked
                                    ? Colors.grey.shade200
                                    : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                slot.isBooked ? 'Réservé' : 'Libre',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: slot.isBooked
                                      ? Colors.grey.shade600
                                      : const Color(0xFF15803D),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    if (_slotValidationError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _slotValidationError!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Modalité du cours particulier',
                subtitle: offer.mode == DeliveryMode.online
                    ? 'En ligne via Jitsi Meet : le lien de la salle de visio sera généré automatiquement dès l\'acceptation par le vendeur.'
                    : 'En présentiel : ${offer.location?.address ?? "Lieu convenu avec le tuteur"}',
                icon: offer.mode == DeliveryMode.online
                    ? Icons.videocam_rounded
                    : Icons.location_on_rounded,
                child: const SizedBox.shrink(),
              ),
            ],

            // 2B. Cas d'une Ressource physique (`resource_physical`) : quantité & adresse de remise
            if (offer.type == OfferType.resourcePhysical) ...[
              _SectionCard(
                title: '1. Quantité et remise en main propre',
                subtitle:
                    'État : ${offer.condition?.label ?? "Bon état"} · Stock disponible : $maxStock exemplaire(s)',
                icon: Icons.inventory_2_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Quantité souhaitée :',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        IconButton.outlined(
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                          icon: const Icon(Icons.remove_rounded, size: 18),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            '$_quantity',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton.outlined(
                          onPressed: _quantity < maxStock
                              ? () => setState(() => _quantity++)
                              : null,
                          icon: const Icon(Icons.add_rounded, size: 18),
                        ),
                      ],
                    ),
                    if (offer.location != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.map_outlined,
                              size: 18,
                              color: Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Lieu de remise (OpenStreetMap) : ${offer.location!.address}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // 2C. Cas d'une Ressource numérique (`resource_digital`) : information de téléchargement privé
            if (offer.type == OfferType.resourceDigital) ...[
              _SectionCard(
                title: '1. Accès au fichier numérique (PDF)',
                subtitle: offer.isFree
                    ? 'Cette ressource est gratuite (0 TND) : le téléchargement sera disponible immédiatement après validation.'
                    : 'Le fichier est stocké en privé sur Cloudinary. Le téléchargement sera débloqué dès l\'acceptation de la commande par le vendeur.',
                icon: Icons.cloud_download_outlined,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          offer.fileSizeLabel ?? 'Document PDF haute résolution',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // 3. Champ de message initial à destination du vendeur (`orders.note`) avec contrôle de saisie
            _SectionCard(
              title: '2. Message pour le vendeur (`orders.note`) *',
              subtitle:
                  'Ce message ouvrira automatiquement la conversation liée à votre commande.',
              icon: Icons.chat_bubble_outline_rounded,
              child: TextFormField(
                controller: _noteController,
                maxLines: 3,
                maxLength: 300,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Veuillez écrire un message au vendeur pour préciser votre demande.';
                  }
                  if (text.length < 10) {
                    return 'Votre message doit contenir au moins 10 caractères (${text.length}/10).';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Votre message ou précision *',
                  hintText: offer.type == OfferType.privateLesson
                      ? 'Ex: Bonjour, j\'aimerais réviser le chapitre sur Dijkstra et les arbres AVL...'
                      : 'Ex: Bonjour, seriez-vous disponible demain à 12h devant la bibliothèque ?',
                  helperText: 'Minimum 10 caractères requis',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 4. Encadré d'information sur le paiement hors-application (Page 7)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.handshake_outlined,
                    color: Color(0xFFD97706),
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paiement hors application',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Le règlement s\'effectue en main propre ou selon les modalités convenues entre étudiant/enseignant dans le chat de la commande.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF92400E),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Barre inférieure : Total en TND + Bouton de validation
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
                    'Total à régler',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    totalPrice <= 0
                        ? 'Gratuit (0 TND)'
                        : '${totalPrice.toStringAsFixed(0)} TND',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _confirmOrder,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: Text(
                      offer.type == OfferType.privateLesson
                          ? 'Verrouiller le créneau & Réserver'
                          : offer.isFree
                              ? 'Obtenir gratuitement'
                              : 'Envoyer la demande de commande',
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
  }
}

/// Carte générique de section utilisée dans l'écran de confirmation de commande
class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Icon(icon, size: 20, color: const Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.grey.shade600,
              height: 1.35,
            ),
          ),
          if (child is! SizedBox) ...[
            const SizedBox(height: 12),
            child,
          ],
        ],
      ),
    );
  }
}
