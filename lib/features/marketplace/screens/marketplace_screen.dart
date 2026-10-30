import 'package:flutter/material.dart';
import '../data/marketplace_mock_data.dart';
import '../models/marketplace_models.dart';
import '../routes/marketplace_routes.dart';
import '../widgets/offer_card.dart';
import '../widgets/review_dialog.dart';

/// Écran racine de l'onglet Marketplace.
/// S'abonne au singleton [MarketplaceController] via [ListenableBuilder] et organise
/// l'interface autour d'un [SegmentedButton] supérieur pilotant un [IndexedStack] à 3 vues :
/// - « Explorer » : catalogue filtrable, recherche, favoris et carrousel de recommandations
/// - « Mes offres » : statistiques vendeur et gestion CRUD des offres et créneaux horaires
/// - « Mes commandes » : suivi des achats et des demandes reçues côté vendeur
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final MarketplaceController _controller = MarketplaceController.instance;

  /// Expression régulière contrôlant la saisie d'un horaire sur 24 heures au format `HH:mm`.
  static final RegExp _timeRegex = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  /// Index actif du [SegmentedButton] supérieur :
  /// `0` = Explorer, `1` = Mes offres, `2` = Mes commandes.
  int _topSectionIndex = 0;

  // État local des critères de filtrage et de tri appliqués au catalogue public
  final TextEditingController _searchController = TextEditingController();
  OfferType? _filterType;
  String? _filterSubject;
  String? _filterLevel;
  double _maxPrice = 100;
  DeliveryMode? _filterMode;
  String? _filterCity;
  double _minRating = 0;
  SellerRole? _filterSellerRole;
  bool _onlyFavorites = false;
  String _sortBy = 'relevance'; // relevance | price_asc | price_desc | rating

  // Filtre de statut actif dans l'onglet vendeur « Mes offres »
  OfferStatus? _myOffersStatusFilter;

  // Sous-bascule de l'onglet « Mes commandes » :
  // `false` = achats effectués (`as=buyer`), `true` = demandes reçues (`as=seller`).
  bool _viewAsSellerOrders = false;
  OrderStatus? _orderStatusFilter;

  @override
  void dispose() {
    // Libération du contrôleur du champ de recherche à la destruction de l'état.
    _searchController.dispose();
    super.dispose();
  }

  /// Décompte les critères de filtrage actifs afin d'alimenter le [Badge] du bouton d'options avancées.
  int get _activeFiltersCount {
    int c = 0;
    if (_filterType != null) c++;
    if (_filterSubject != null) c++;
    if (_filterLevel != null) c++;
    if (_maxPrice < 100) c++;
    if (_filterMode != null) c++;
    if (_filterCity != null) c++;
    if (_minRating > 0) c++;
    if (_filterSellerRole != null) c++;
    if (_onlyFavorites) c++;
    return c;
  }

  /// Réinitialise l'ensemble des filtres et le tri du catalogue
  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _filterType = null;
      _filterSubject = null;
      _filterLevel = null;
      _maxPrice = 100;
      _filterMode = null;
      _filterCity = null;
      _minRating = 0;
      _filterSellerRole = null;
      _onlyFavorites = false;
      _sortBy = 'relevance';
    });
  }

  /// Filtre et trie les offres publiques selon les critères sélectionnés
  /// Endpoint simulé : `GET /offers?type=&subject=&level=&maxPrice=&mode=&city=&sellerRole=&sort=`
  List<Offer> _getFilteredCatalogOffers() {
    final query = _searchController.text.trim().toLowerCase();
    final list = _controller.allOffers.where((o) {
      // Seules les offres publiées apparaissent dans le catalogue (les offres masquées après 3 signalements sont exclues)
      if (o.status != OfferStatus.published) return false;
      if (_onlyFavorites && !_controller.isFavorite(o.id)) return false;
      if (_filterType != null && o.type != _filterType) return false;
      if (_filterSubject != null && o.subject != _filterSubject) return false;
      if (_filterLevel != null && o.level != _filterLevel) return false;
      if (o.price > _maxPrice) return false;
      if (_filterMode != null && o.mode != _filterMode) return false;
      if (_filterCity != null && o.location?.city != _filterCity) return false;
      if (_minRating > 0 && o.ratingAvg < _minRating) return false;
      if (_filterSellerRole != null && o.sellerRole != _filterSellerRole) {
        return false;
      }
      if (query.isNotEmpty) {
        final matchTitle = o.title.toLowerCase().contains(query);
        final matchDesc = o.description.toLowerCase().contains(query);
        final matchSub = o.subject.toLowerCase().contains(query);
        final matchSeller = o.sellerName.toLowerCase().contains(query);
        if (!matchTitle && !matchDesc && !matchSub && !matchSeller) {
          return false;
        }
      }
      return true;
    }).toList();

    // Application du critère de tri (`sort`)
    switch (_sortBy) {
      case 'price_asc':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_desc':
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'rating':
        list.sort((a, b) => b.ratingAvg.compareTo(a.ratingAvg));
        break;
      case 'relevance':
      default:
        list.sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
        break;
    }
    return list;
  }

  /// Affiche une feuille modale redimensionnable ([DraggableScrollableSheet]) combinée à un
  /// [StatefulBuilder] pour synchroniser immédiatement l'état local des [ChoiceChip] et du [Slider]
  /// avec la liste filtrée en arrière-plan.
  void _openAdvancedFiltersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          void updateFilter(VoidCallback fn) {
            setModalState(fn);
            setState(() {});
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.82,
            maxChildSize: 0.92,
            minChildSize: 0.5,
            builder: (_, scrollCtrl) => ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Filtres & Tri du Catalogue (M5)',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _resetFilters();
                        setModalState(() {});
                      },
                      child: const Text('Réinitialiser'),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // 1. Tri par pertinence, prix ou note
                const Text(
                  'Trier par (`sort`)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ('relevance', 'Pertinence'),
                    ('price_asc', 'Prix croissant'),
                    ('price_desc', 'Prix décroissant'),
                    ('rating', 'Meilleure note ★'),
                  ].map((item) {
                    return ChoiceChip(
                      selected: _sortBy == item.$1,
                      onSelected: (_) => updateFilter(() => _sortBy = item.$1),
                      label: Text(item.$2),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // 2. Origine du vendeur (Étudiant ou Enseignant vérifié)
                const Text(
                  'Origine du vendeur (`sellerRole`)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      selected: _filterSellerRole == null,
                      onSelected: (_) =>
                          updateFilter(() => _filterSellerRole = null),
                      label: const Text('Tous'),
                    ),
                    ChoiceChip(
                      selected: _filterSellerRole == SellerRole.teacher,
                      onSelected: (_) => updateFilter(
                        () => _filterSellerRole = SellerRole.teacher,
                      ),
                      label: const Text('Enseignant vérifié'),
                    ),
                    ChoiceChip(
                      selected: _filterSellerRole == SellerRole.student,
                      onSelected: (_) => updateFilter(
                        () => _filterSellerRole = SellerRole.student,
                      ),
                      label: const Text('Offre étudiant'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Matière académique
                const Text(
                  'Matière (`subject`)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      selected: _filterSubject == null,
                      onSelected: (_) =>
                          updateFilter(() => _filterSubject = null),
                      label: const Text('Toutes'),
                    ),
                    ...MarketplaceController.subjects.map(
                      (sub) => ChoiceChip(
                        selected: _filterSubject == sub,
                        onSelected: (_) =>
                            updateFilter(() => _filterSubject = sub),
                        label: Text(sub),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 4. Niveau d'études
                const Text(
                  'Niveau d\'études (`level`)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      selected: _filterLevel == null,
                      onSelected: (_) =>
                          updateFilter(() => _filterLevel = null),
                      label: const Text('Tous'),
                    ),
                    ...MarketplaceController.levels.map(
                      (lvl) => ChoiceChip(
                        selected: _filterLevel == lvl,
                        onSelected: (_) =>
                            updateFilter(() => _filterLevel = lvl),
                        label: Text(lvl),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 5. Prix maximum en Dinars Tunisiens (TND)
                Row(
                  children: [
                    const Text(
                      'Prix maximum (`maxPrice`)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _maxPrice == 0
                          ? 'Gratuit uniquement (0 TND)'
                          : '${_maxPrice.toInt()} TND max',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _maxPrice,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  onChanged: (v) => updateFilter(() => _maxPrice = v),
                ),
                const SizedBox(height: 8),

                // 6. Mode (En ligne Jitsi / Présentiel) & Ville (OpenStreetMap Nominatim)
                const Text(
                  'Mode (`mode`) & Ville (`city`)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      selected: _filterMode == null,
                      onSelected: (_) => updateFilter(() => _filterMode = null),
                      label: const Text('Tous modes'),
                    ),
                    ChoiceChip(
                      selected: _filterMode == DeliveryMode.online,
                      onSelected: (_) => updateFilter(
                        () => _filterMode = DeliveryMode.online,
                      ),
                      label: const Text('En ligne (Jitsi)'),
                    ),
                    ChoiceChip(
                      selected: _filterMode == DeliveryMode.onsite,
                      onSelected: (_) => updateFilter(
                        () => _filterMode = DeliveryMode.onsite,
                      ),
                      label: const Text('En présentiel'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      selected: _filterCity == null,
                      onSelected: (_) => updateFilter(() => _filterCity = null),
                      label: const Text('Toutes les villes'),
                    ),
                    ...MarketplaceController.cities.map(
                      (c) => ChoiceChip(
                        selected: _filterCity == c,
                        onSelected: (_) => updateFilter(() => _filterCity = c),
                        label: Text(c),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 7. Note minimale ★
                const Text(
                  'Note minimale ★',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    (0.0, 'Toutes'),
                    (4.0, '4.0 ★ et +'),
                    (4.5, '4.5 ★ et +'),
                    (4.8, '4.8 ★ et +'),
                  ].map((r) {
                    return ChoiceChip(
                      selected: _minRating == r.$1,
                      onSelected: (_) =>
                          updateFilter(() => _minRating = r.$1),
                      label: Text(r.$2),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                    ),
                    child: const Text(
                      'Appliquer les filtres',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Ouvre la feuille modale de gestion des créneaux horaires (`availabilities`) d'un cours particulier.
  /// S'appuie sur [ListenableBuilder] pour rafraîchir la liste en direct, compense le clavier via
  /// `MediaQuery.of(ctx).viewInsets.bottom`, bloque la suppression des créneaux déjà réservés (`isBooked`)
  /// et valide le formulaire d'ajout ([Form] + [GlobalKey<FormState>] + `_timeRegex`).
  void _openManageSlotsModal(Offer offer) {
    final slotFormKey = GlobalKey<FormState>();
    final dateCtrl = TextEditingController(text: 'Sam 31 Oct 2026');
    final startCtrl = TextEditingController(text: '14:00');
    final endCtrl = TextEditingController(text: '15:00');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ListenableBuilder(
        listenable: _controller,
        builder: (ctx, _) {
          final slots = _controller.getSlotsForOffer(offer.id);
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
            child: Form(
              key: slotFormKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        color: Color(0xFF7C3AED),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Créneaux (`availabilities` CRUD) — ${offer.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...slots.map(
                    (slot) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        slot.isBooked
                            ? Icons.lock_rounded
                            : Icons.event_available_rounded,
                        color: slot.isBooked
                            ? const Color(0xFFD97706)
                            : const Color(0xFF16A34A),
                      ),
                      title: Text(
                        '${slot.date} · ${slot.startTime} - ${slot.endTime}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        slot.isBooked
                            ? 'Créneau réservé (verrouillé par commande)'
                            : 'Libre à la réservation',
                      ),
                      trailing: slot.isBooked
                          ? null
                          : IconButton(
                              onPressed: () =>
                                  _controller.removeAvailabilitySlot(
                                offer.id,
                                slot.id,
                              ),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                    ),
                  ),
                  const Divider(height: 20),
                  const Text(
                    'Ajouter un nouveau créneau horaire *',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: dateCtrl,
                          validator: (v) {
                            if (v == null || v.trim().length < 5) {
                              return 'Date requise';
                            }
                            return null;
                          },
                          decoration: const InputDecoration(
                            labelText: 'Date *',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: startCtrl,
                          validator: (v) {
                            if (v == null || !_timeRegex.hasMatch(v.trim())) {
                              return 'HH:mm';
                            }
                            return null;
                          },
                          decoration: const InputDecoration(
                            labelText: 'Début *',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: endCtrl,
                          validator: (v) {
                            final text = v?.trim() ?? '';
                            if (!_timeRegex.hasMatch(text)) {
                              return 'HH:mm';
                            }
                            final start = startCtrl.text.trim();
                            if (_timeRegex.hasMatch(start) &&
                                text.compareTo(start) <= 0) {
                              return '> Début';
                            }
                            return null;
                          },
                          decoration: const InputDecoration(
                            labelText: 'Fin *',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (slotFormKey.currentState!.validate()) {
                          _controller.addAvailabilitySlot(
                            offer.id,
                            dateCtrl.text.trim(),
                            startCtrl.text.trim(),
                            endCtrl.text.trim(),
                          );
                        }
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Ajouter ce créneau'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Affiche une boîte de dialogue de confirmation avant la suppression d'une offre (`DELETE /offers/:id`)
  void _confirmDeleteOffer(Offer offer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Confirmer la suppression',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Voulez-vous vraiment supprimer définitivement l\'offre « ${offer.title} » ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              _controller.deleteOffer(offer.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Offre supprimée (DELETE /offers/:id).'),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        // Nombre de demandes en attente côté vendeur signalé par un Badge sur le segment « Mes commandes »
        final pendingSellerRequestsCount = _controller.receivedOrders
            .where((o) => o.status == OrderStatus.requested)
            .length;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Column(
            children: [
              // Barre supérieure hébergeant le SegmentedButton de navigation entre les 3 sections
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: [
                          const ButtonSegment(
                            value: 0,
                            icon: Icon(Icons.explore_outlined, size: 18),
                            label: Text('Explorer'),
                          ),
                          ButtonSegment(
                            value: 1,
                            icon: const Icon(
                              Icons.storefront_outlined,
                              size: 18,
                            ),
                            label: Text(
                              'Mes offres (${_controller.myOffers.length})',
                            ),
                          ),
                          ButtonSegment(
                            value: 2,
                            icon: Badge(
                              isLabelVisible: pendingSellerRequestsCount > 0,
                              label: Text('$pendingSellerRequestsCount'),
                              child: const Icon(
                                Icons.receipt_long_outlined,
                                size: 18,
                              ),
                            ),
                            label: const Text('Mes commandes'),
                          ),
                        ],
                        selected: {_topSectionIndex},
                        onSelectionChanged: (s) =>
                            setState(() => _topSectionIndex = s.first),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // IndexedStack conservant l'état et la position de défilement de chaque vue lors du changement d'onglet
              Expanded(
                child: IndexedStack(
                  index: _topSectionIndex,
                  children: [
                    _buildExplorerView(),
                    _buildMyOffersView(),
                    _buildMyOrdersView(),
                  ],
                ),
              ),
            ],
          ),
          // Bouton d'action flottant étendu affiché uniquement sur « Mes offres » pour pousser l'assistant de création
          floatingActionButton: _topSectionIndex == 1
              ? FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      MarketplaceRoutes.offerWizard,
                    );
                  },
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'Nouvelle offre',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                )
              : null,
        );
      },
    );
  }

  /// Construit la vue « Explorer » : barre de recherche, puces [FilterChip] rapides,
  /// carrousel horizontal des offres rattachées aux cours suivis et liste principale de [OfferCard].
  Widget _buildExplorerView() {
    final catalogOffers = _getFilteredCatalogOffers();
    final recommendedOffers = _controller.allOffers
        .where(
          (o) => o.status == OfferStatus.published && o.isRecommendedByCourse,
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Barre de recherche par mot-clé + Bouton Filtres avancés + Bouton Favoris ♥
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText:
                      'Rechercher une ressource, un tuteur, une matière...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear_rounded, size: 18),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Badge(
              isLabelVisible: _activeFiltersCount > 0,
              label: Text('$_activeFiltersCount'),
              child: IconButton.filledTonal(
                tooltip: 'Filtres avancés & Tri',
                onPressed: _openAdvancedFiltersSheet,
                icon: const Icon(Icons.tune_rounded),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              tooltip: 'Afficher uniquement mes favoris',
              style: IconButton.styleFrom(
                backgroundColor:
                    _onlyFavorites ? const Color(0xFFFEE2E2) : null,
              ),
              onPressed: () =>
                  setState(() => _onlyFavorites = !_onlyFavorites),
              icon: Icon(
                _onlyFavorites
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: _onlyFavorites ? const Color(0xFFEF4444) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 2. Puces de filtrage rapide par Type d'offre & Enseignant vérifié
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                selected: _filterType == null && _filterSellerRole == null,
                onSelected: (_) => setState(() {
                  _filterType = null;
                  _filterSellerRole = null;
                }),
                label: const Text('Tout voir'),
              ),
              const SizedBox(width: 8),
              ...OfferType.values.map((t) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(t.icon, size: 16, color: t.color),
                    selected: _filterType == t,
                    onSelected: (sel) =>
                        setState(() => _filterType = sel ? t : null),
                    label: Text(t.label),
                  ),
                );
              }),
              FilterChip(
                avatar: const Icon(
                  Icons.verified_rounded,
                  size: 16,
                  color: Color(0xFF2563EB),
                ),
                selected: _filterSellerRole == SellerRole.teacher,
                onSelected: (sel) => setState(
                  () => _filterSellerRole = sel ? SellerRole.teacher : null,
                ),
                label: const Text('Enseignant vérifié'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 3. Carrousel horizontal des offres recommandées (affiché hors recherche/filtrage actif)
        if (recommendedOffers.isNotEmpty &&
            _activeFiltersCount == 0 &&
            _searchController.text.isEmpty) ...[
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Recommandées d\'après vos cours suivis (L6)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'GET /offers/recommended',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 260,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recommendedOffers.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, idx) {
                final rec = recommendedOffers[idx];
                return SizedBox(
                  width: 310,
                  child: OfferCard(
                    offer: rec,
                    compact: true,
                    isFavorite: _controller.isFavorite(rec.id),
                    onFavoriteToggle: () => _controller.toggleFavorite(rec.id),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        MarketplaceRoutes.offerDetail,
                        arguments: OfferDetailArgs(offerId: rec.id),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],

        // 4. Liste principale des offres du Catalogue
        Row(
          children: [
            Text(
              'Catalogue des offres (${catalogOffers.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  MarketplaceRoutes.offerWizard,
                );
              },
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text('Vendre / Donner un cours'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (catalogOffers.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Aucune offre ne correspond à vos filtres',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _resetFilters,
                  child: const Text('Réinitialiser les filtres'),
                ),
              ],
            ),
          )
        else
          ...catalogOffers.map(
            (offer) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OfferCard(
                offer: offer,
                isFavorite: _controller.isFavorite(offer.id),
                onFavoriteToggle: () => _controller.toggleFavorite(offer.id),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    MarketplaceRoutes.offerDetail,
                    arguments: OfferDetailArgs(offerId: offer.id),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  /// Construit la vue « Mes offres » : indicateurs agrégés du vendeur (`GET /seller/stats`),
  /// filtrage par [OfferStatus] via [ChoiceChip] et actions CRUD par offre (publier/masquer, modifier, créneaux, supprimer).
  Widget _buildMyOffersView() {
    final myOffers = _controller.myOffers;
    final filteredMyOffers = _myOffersStatusFilter == null
        ? myOffers
        : myOffers.where((o) => o.status == _myOffersStatusFilter).toList();

    final totalViews =
        myOffers.fold<int>(0, (sum, item) => sum + item.viewsCount);
    final totalSales =
        myOffers.fold<int>(0, (sum, item) => sum + item.salesCount);
    final lessonsGiven = myOffers
        .where((o) => o.type == OfferType.privateLesson)
        .fold<int>(0, (sum, item) => sum + item.salesCount);
    final ratedOffers = myOffers.where((o) => o.ratingCount > 0).toList();
    final avgSellerRating = ratedOffers.isEmpty
        ? 0.0
        : ratedOffers.fold<double>(0, (s, o) => s + o.ratingAvg) /
            ratedOffers.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        // 1. Carte récapitulative des statistiques vendeur (vues cumulées, ventes, séances et moyenne)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.analytics_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Tableau de bord vendeur (GET /seller/stats)',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _controller.currentUserRole.badgeLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _SellerStatBox(
                    value: '$totalViews',
                    label: 'Vues totales',
                    icon: Icons.visibility_outlined,
                  ),
                  const SizedBox(width: 8),
                  _SellerStatBox(
                    value: '$totalSales',
                    label: 'Ventes',
                    icon: Icons.shopping_bag_outlined,
                  ),
                  const SizedBox(width: 8),
                  _SellerStatBox(
                    value: '$lessonsGiven',
                    label: 'Séances (1h)',
                    icon: Icons.co_present_outlined,
                  ),
                  const SizedBox(width: 8),
                  _SellerStatBox(
                    value: avgSellerRating > 0
                        ? '${avgSellerRating.toStringAsFixed(2)} ★'
                        : '-',
                    label: 'Note moyenne',
                    icon: Icons.star_outline_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Récapitulatif des paliers de badges liés à l'activité vendeur (première vente, séances données, note moyenne)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      color: Color(0xFFFDE047),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Badges M5 débloqués : Vendeur (1re vente) · Mentor (5 cours particuliers) · Bien noté (≥ 4.5/5)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Filtres par statut d'offre (`published`, `draft`, `sold_out`, `hidden`)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                selected: _myOffersStatusFilter == null,
                onSelected: (_) =>
                    setState(() => _myOffersStatusFilter = null),
                label: Text('Toutes (${myOffers.length})'),
              ),
              const SizedBox(width: 8),
              ...OfferStatus.values.map((st) {
                final count = myOffers.where((o) => o.status == st).length;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: _myOffersStatusFilter == st,
                    onSelected: (_) =>
                        setState(() => _myOffersStatusFilter = st),
                    label: Text('${st.label} ($count)'),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3. Liste des offres du vendeur avec actions CRUD complètes
        ...filteredMyOffers.map((offer) {
          final slotsCount = _controller.getSlotsForOffer(offer.id).length;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
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
                    Icon(offer.type.icon, size: 18, color: offer.type.color),
                    const SizedBox(width: 6),
                    Text(
                      offer.type.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: offer.type.color,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: offer.status.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        offer.status.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: offer.status.color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      MarketplaceRoutes.offerDetail,
                      arguments: OfferDetailArgs(offerId: offer.id),
                    );
                  },
                  child: Text(
                    offer.title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${offer.formattedPrice} · ${offer.viewsCount} vues · ${offer.salesCount} ventes',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const Divider(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (offer.status == OfferStatus.published)
                      OutlinedButton.icon(
                        onPressed: () => _controller.updateOfferStatus(
                          offer.id,
                          OfferStatus.hidden,
                        ),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        icon:
                            const Icon(Icons.visibility_off_outlined, size: 16),
                        label: const Text('Masquer'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: () => _controller.updateOfferStatus(
                          offer.id,
                          OfferStatus.published,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.publish_rounded, size: 16),
                        label: const Text('Publier'),
                      ),
                    // Ouvre OfferWizardScreen en mode édition en transmettant OfferWizardArgs
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          MarketplaceRoutes.offerWizard,
                          arguments: OfferWizardArgs(existingOffer: offer),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Modifier'),
                    ),
                    if (offer.type == OfferType.privateLesson)
                      OutlinedButton.icon(
                        onPressed: () => _openManageSlotsModal(offer),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        icon:
                            const Icon(Icons.calendar_month_rounded, size: 16),
                        label: Text('Créneaux ($slotsCount)'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          MarketplaceRoutes.offerDetail,
                          arguments: OfferDetailArgs(offerId: offer.id),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Aperçu'),
                    ),
                    IconButton(
                      tooltip: 'Supprimer cette offre',
                      onPressed: () => _confirmDeleteOffer(offer),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFDC2626),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// Construit la vue « Mes commandes » : bascule acheteur/vendeur, filtre par [OrderStatus]
  /// et cartes de suivi donnant accès au chat, aux transitions de statut et au dépôt d'avis.
  Widget _buildMyOrdersView() {
    final buyerOrders = _controller.myPurchases;
    final sellerOrders = _controller.receivedOrders;
    final baseList = _viewAsSellerOrders ? sellerOrders : buyerOrders;
    final filteredOrders = _orderStatusFilter == null
        ? baseList
        : baseList.where((o) => o.status == _orderStatusFilter).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Sous-bascule : Mes achats (Acheteur) | Demandes reçues (Vendeur)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _viewAsSellerOrders = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_viewAsSellerOrders
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        'Mes achats (${buyerOrders.length})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: !_viewAsSellerOrders
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _viewAsSellerOrders = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _viewAsSellerOrders
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        'Demandes reçues (${sellerOrders.length})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _viewAsSellerOrders
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. Filtres par statut de commande (`requested`, `accepted`, `completed`, `rejected`, `cancelled`)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                selected: _orderStatusFilter == null,
                onSelected: (_) => setState(() => _orderStatusFilter = null),
                label: const Text('Tous les statuts'),
              ),
              const SizedBox(width: 8),
              ...OrderStatus.values.map((st) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: _orderStatusFilter == st,
                    onSelected: (_) => setState(() => _orderStatusFilter = st),
                    label: Text(st.label),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3. Liste des cartes de commandes
        if (filteredOrders.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text(
                'Aucune commande dans cette catégorie.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...filteredOrders.map(
            (order) => _OrderCard(
              order: order,
              isSellerView: _viewAsSellerOrders,
              onOpenChat: () {
                Navigator.pushNamed(
                  context,
                  MarketplaceRoutes.orderChat,
                  arguments: OrderChatArgs(orderId: order.id),
                );
              },
              onUpdateStatus: (newStatus) {
                _controller.updateOrderStatus(order.id, newStatus);
              },
              onLeaveReview: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (_) => ReviewBottomSheet(
                    order: order,
                    onSubmit: (rating, comment) {
                      _controller.submitReview(
                        order: order,
                        rating: rating,
                        comment: comment,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Avis publié ! Note moyenne de l\'offre et du vendeur mise à jour.',
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Boîte de statistique individuelle dans le Tableau de bord vendeur (`GET /seller/stats`)
class _SellerStatBox extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _SellerStatBox({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte représentant une commande ou réservation dans la vue « Mes commandes »
class _OrderCard extends StatelessWidget {
  final MarketplaceOrder order;
  final bool isSellerView;
  final VoidCallback onOpenChat;
  final void Function(OrderStatus) onUpdateStatus;
  final VoidCallback onLeaveReview;

  const _OrderCard({
    required this.order,
    required this.isSellerView,
    required this.onOpenChat,
    required this.onUpdateStatus,
    required this.onLeaveReview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : Type d'offre + Badge Statut de la commande
          Row(
            children: [
              Icon(order.offerType.icon, size: 17, color: order.offerType.color),
              const SizedBox(width: 6),
              Text(
                order.offerType.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: order.offerType.color,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: order.status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(order.status.icon, size: 13, color: order.status.color),
                    const SizedBox(width: 4),
                    Text(
                      order.status.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: order.status.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            order.offerTitle,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isSellerView
                ? 'Acheteur : ${order.buyerName} · Montant : ${order.amount.toStringAsFixed(0)} TND'
                : 'Vendeur : ${order.sellerName} (${order.sellerRole.badgeLabel}) · ${order.amount.toStringAsFixed(0)} TND',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          if (order.slotLabel != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: Color(0xFF7C3AED),
                ),
                const SizedBox(width: 4),
                Text(
                  'Créneau réservé : ${order.slotLabel}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ],
            ),
          ],
          if (order.meetingLink != null &&
              order.status == OrderStatus.accepted) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.videocam_rounded,
                  size: 15,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Salle Jitsi : ${order.meetingLink}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 20),

          // Barre d'actions adaptative (Wrap) selon le point de vue acheteur/vendeur et l'état de la commande
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Bouton d'accès à OrderChatScreen surmonté d'un Badge indiquant les messages non lus
              Badge(
                isLabelVisible: order.unreadCount > 0,
                label: Text('${order.unreadCount}'),
                child: OutlinedButton.icon(
                  onPressed: onOpenChat,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Chat commande'),
                ),
              ),

              if (isSellerView && order.status == OrderStatus.requested) ...[
                FilledButton.icon(
                  onPressed: () => onUpdateStatus(OrderStatus.accepted),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Accepter'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onUpdateStatus(OrderStatus.rejected),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Refuser'),
                ),
              ],

              if (isSellerView && order.status == OrderStatus.accepted)
                FilledButton.icon(
                  onPressed: () => onUpdateStatus(OrderStatus.completed),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.task_alt_rounded, size: 16),
                  label: const Text('Terminer la commande'),
                ),

              if (!isSellerView && order.status == OrderStatus.requested)
                TextButton.icon(
                  onPressed: () => onUpdateStatus(OrderStatus.cancelled),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Annuler'),
                ),

              if (!isSellerView &&
                  order.offerType == OfferType.resourceDigital &&
                  (order.status == OrderStatus.accepted ||
                      order.status == OrderStatus.completed))
                FilledButton.tonalIcon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Téléchargement du fichier PDF (GET /orders/:id/download)...',
                        ),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Télécharger PDF'),
                ),

              if (!isSellerView &&
                  order.status == OrderStatus.completed &&
                  !order.hasReview)
                FilledButton.icon(
                  onPressed: onLeaveReview,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.star_rounded, size: 16),
                  label: const Text('Laisser un avis ★'),
                ),

              if (!isSellerView && order.hasReview)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '★ Avis publié',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
