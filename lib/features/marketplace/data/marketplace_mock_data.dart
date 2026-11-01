import 'package:flutter/foundation.dart';
import '../models/marketplace_models.dart';

/// Contrôleur central de la Marketplace basé sur [ChangeNotifier].
/// Expose un singleton partagé ([instance]) observé par les différents écrans
/// via `ListenableBuilder` afin de propager chaque mutation d'état (`notifyListeners()`)
/// entre le catalogue, la fiche détail, l'assistant d'offre, les commandes et le chat.
class MarketplaceController extends ChangeNotifier {
  /// Instance unique partagée dans toute la fonctionnalité Marketplace.
  static final MarketplaceController instance = MarketplaceController._internal();

  /// Constructeur privé initialisant le jeu de données en mémoire au démarrage.
  MarketplaceController._internal() {
    _seedInitialData();
  }

  /// Identité et rôle de l'utilisateur courant simulé (`users.uid` et `users.role`).
  String currentUserId = 'user_me';
  String currentUserName = 'Yasmine Ben Ali';
  SellerRole currentUserRole = SellerRole.student;

  /// Bascule le profil actif entre étudiant et enseignant vérifié, puis notifie
  /// les vues abonnées via [notifyListeners] pour rafraîchir les badges dépendants du rôle.
  void toggleCurrentUserRole() {
    if (currentUserRole == SellerRole.student) {
      currentUserRole = SellerRole.teacher;
      currentUserName = 'Pr. Karim Mansouri';
    } else {
      currentUserRole = SellerRole.student;
      currentUserName = 'Yasmine Ben Ali';
    }
    notifyListeners();
  }

  // Collections en mémoire reflétant la structure des collections Firestore
  // (`offers`, `favorites`, `availabilities`, `orders`, `reviews`, `conversations`).
  final List<Offer> _offers = [];
  final Set<String> _favoriteOfferIds = {'offer_1', 'offer_3'};
  final Map<String, List<AvailabilitySlot>> _slotsByOffer = {};
  final List<MarketplaceOrder> _orders = [];
  final List<OfferReview> _reviews = [];
  final Map<String, List<ChatMessage>> _messagesByOrder = {};

  // Accesseurs exposant des vues non modifiables (`unmodifiable`) pour préserver l'encapsulation.
  List<Offer> get allOffers => List.unmodifiable(_offers);
  Set<String> get favoriteOfferIds => Set.unmodifiable(_favoriteOfferIds);
  List<MarketplaceOrder> get allOrders => List.unmodifiable(_orders);
  List<OfferReview> get allReviews => List.unmodifiable(_reviews);

  /// Référentiel des matières académiques proposées dans les filtres et le formulaire d'offre.
  static const List<String> subjects = [
    'Algorithmique',
    'Bases de Données',
    'Réseaux & Sécurité',
    'Intelligence Artificielle',
    'Génie Logiciel',
    'Mathématiques',
    'Développement Mobile',
  ];

  /// Niveaux d'études universitaires disponibles (de la licence au master).
  static const List<String> levels = [
    'L1',
    'L2',
    'L3',
    'M1',
    'M2',
  ];

  /// Villes universitaires utilisées pour le filtrage géographique et la géolocalisation Nominatim.
  static const List<String> cities = [
    'Tunis',
    'Ariana',
    'Manouba',
    'Sousse',
    'Sfax',
    'Monastir',
  ];

  /// Catalogue des cours académiques pouvant être rattachés optionnellement à une offre.
  static const List<Map<String, String>> availableCoursesL6 = [
    {
      'id': 'course_algo_1',
      'title': 'Algorithmique & Structures de Données (Chapitres 1–6)',
      'subject': 'Algorithmique',
    },
    {
      'id': 'course_bdd_2',
      'title': 'Bases de Données Relationnelles & SQL Avancé',
      'subject': 'Bases de Données',
    },
    {
      'id': 'course_ia_3',
      'title': 'Machine Learning & Réseaux de Neurones',
      'subject': 'Intelligence Artificielle',
    },
    {
      'id': 'course_flutter_4',
      'title': 'Architecture Mobile Cross-Platform (Flutter & NestJS)',
      'subject': 'Développement Mobile',
    },
  ];

  /// Indique si l'offre [offerId] figure dans l'ensemble des favoris de l'utilisateur courant.
  bool isFavorite(String offerId) => _favoriteOfferIds.contains(offerId);

  /// Bascule l'état favori d'une offre (`PUT | DELETE /favorites`) et déclenche [notifyListeners].
  void toggleFavorite(String offerId) {
    if (_favoriteOfferIds.contains(offerId)) {
      _favoriteOfferIds.remove(offerId);
    } else {
      _favoriteOfferIds.add(offerId);
    }
    notifyListeners();
  }

  /// Retourne une vue non modifiable des créneaux horaires associés à l'offre [offerId].
  List<AvailabilitySlot> getSlotsForOffer(String offerId) {
    return List.unmodifiable(_slotsByOffer[offerId] ?? const []);
  }

  /// Filtre et retourne les avis vérifiés rattachés à l'offre [offerId] (`GET /reviews`).
  List<OfferReview> getReviewsForOffer(String offerId) {
    return _reviews.where((r) => r.offerId == offerId).toList();
  }

  /// Retourne l'historique chronologique des messages de la commande [orderId].
  List<ChatMessage> getMessagesForOrder(String orderId) {
    return List.unmodifiable(_messagesByOrder[orderId] ?? const []);
  }

  /// Offres dont le vendeur correspond à l'utilisateur courant (onglet « Mes offres »).
  List<Offer> get myOffers =>
      _offers.where((o) => o.sellerId == currentUserId).toList();

  /// Commandes passées par l'utilisateur courant en tant qu'acheteur (`GET /orders/me?as=buyer`).
  List<MarketplaceOrder> get myPurchases =>
      _orders.where((o) => o.buyerId == currentUserId).toList();

  /// Demandes de commandes reçues par l'utilisateur courant en tant que vendeur (`GET /orders/me?as=seller`).
  List<MarketplaceOrder> get receivedOrders =>
      _orders.where((o) => o.sellerId == currentUserId).toList();

  /// Incrémente le compteur de consultations d'une offre (`GET /offers/:id`) via `copyWith`.
  void incrementViewCount(String offerId) {
    final idx = _offers.indexWhere((o) => o.id == offerId);
    if (idx != -1) {
      _offers[idx] = _offers[idx].copyWith(
        viewsCount: _offers[idx].viewsCount + 1,
      );
      notifyListeners();
    }
  }

  /// Insère une nouvelle offre en tête du catalogue (`POST /offers`) ainsi que ses éventuels créneaux.
  void addOffer(Offer offer, {List<AvailabilitySlot> slots = const []}) {
    _offers.insert(0, offer);
    if (slots.isNotEmpty) {
      _slotsByOffer[offer.id] = List.from(slots);
    }
    notifyListeners();
  }

  /// Remplace une offre existante (`PATCH /offers/:id`) et met à jour ses créneaux horaires si fournis.
  void updateOffer(Offer updatedOffer, {List<AvailabilitySlot>? slots}) {
    final idx = _offers.indexWhere((o) => o.id == updatedOffer.id);
    if (idx != -1) {
      _offers[idx] = updatedOffer;
      if (slots != null) {
        _slotsByOffer[updatedOffer.id] = List.from(slots);
      }
      notifyListeners();
    }
  }

  /// Modifie la visibilité d'une offre (`published`, `hidden`, `draft`) et rafraîchit l'interface.
  void updateOfferStatus(String offerId, OfferStatus newStatus) {
    final idx = _offers.indexWhere((o) => o.id == offerId);
    if (idx != -1) {
      _offers[idx] = _offers[idx].copyWith(status: newStatus);
      notifyListeners();
    }
  }

  /// Supprime définitivement une offre ainsi que ses créneaux associés (`DELETE /offers/:id`).
  void deleteOffer(String offerId) {
    _offers.removeWhere((o) => o.id == offerId);
    _slotsByOffer.remove(offerId);
    notifyListeners();
  }

  /// Ajoute un créneau horaire libre à un cours particulier (`POST /availabilities`).
  void addAvailabilitySlot(String offerId, String date, String startTime, String endTime) {
    final list = _slotsByOffer.putIfAbsent(offerId, () => []);
    list.add(
      AvailabilitySlot(
        id: 'slot_${DateTime.now().millisecondsSinceEpoch}',
        offerId: offerId,
        sellerId: currentUserId,
        date: date,
        startTime: startTime,
        endTime: endTime,
      ),
    );
    notifyListeners();
  }

  /// Supprime un créneau horaire uniquement s'il n'est pas déjà verrouillé par une réservation (`!s.isBooked`).
  void removeAvailabilitySlot(String offerId, String slotId) {
    _slotsByOffer[offerId]?.removeWhere((s) => s.id == slotId && !s.isBooked);
    notifyListeners();
  }

  /// Incrémente le compteur de signalements d'une offre (`POST /reports`).
  /// Dès que le seuil de 3 signalements est atteint, l'offre passe automatiquement
  /// au statut [OfferStatus.hidden] pour la retirer du catalogue public.
  bool reportOffer(String offerId, String reason) {
    final idx = _offers.indexWhere((o) => o.id == offerId);
    if (idx == -1) return false;
    final newReportsCount = _offers[idx].reportsCount + 1;
    final autoHidden = newReportsCount >= 3;
    _offers[idx] = _offers[idx].copyWith(
      reportsCount: newReportsCount,
      status: autoHidden ? OfferStatus.hidden : _offers[idx].status,
    );
    notifyListeners();
    return autoHidden;
  }

  /// Enregistre une nouvelle commande ou réservation (`POST /orders`) :
  /// - Positionne le statut initial sur [OrderStatus.requested], ou directement sur
  ///   [OrderStatus.accepted] lorsqu'il s'agit d'une ressource numérique gratuite.
  /// - Verrouille immédiatement le créneau sélectionné (`isBooked: true`) pour empêcher
  ///   toute double réservation concurrente sur le même horaire.
  /// - Initialise le fil de discussion dédié (`conversations/{orderId}`) avec un message système
  ///   suivi de la note initiale de l'acheteur.
  MarketplaceOrder createOrder({
    required Offer offer,
    int quantity = 1,
    AvailabilitySlot? selectedSlot,
    required String note,
  }) {
    final orderId = 'ord_${DateTime.now().millisecondsSinceEpoch}';
    final isImmediateFreeDigital =
        offer.type == OfferType.resourceDigital && offer.isFree;

    // Verrouillage du créneau horaire s'il s'agit d'un cours particulier
    if (selectedSlot != null) {
      final slots = _slotsByOffer[offer.id];
      if (slots != null) {
        final sIdx = slots.indexWhere((s) => s.id == selectedSlot.id);
        if (sIdx != -1) {
          slots[sIdx] = slots[sIdx].copyWith(
            isBooked: true,
            orderId: orderId,
          );
        }
      }
    }

    final newOrder = MarketplaceOrder(
      id: orderId,
      offerId: offer.id,
      offerTitle: offer.title,
      offerType: offer.type,
      offerSubject: offer.subject,
      buyerId: currentUserId,
      buyerName: currentUserName,
      sellerId: offer.sellerId,
      sellerName: offer.sellerName,
      sellerRole: offer.sellerRole,
      quantity: quantity,
      amount: offer.price * quantity,
      slotId: selectedSlot?.id,
      slotLabel: selectedSlot != null
          ? '${selectedSlot.date} · ${selectedSlot.startTime} - ${selectedSlot.endTime}'
          : null,
      pickupAddress: offer.location?.address,
      fileUrl: offer.fileUrl,
      status: isImmediateFreeDigital
          ? OrderStatus.accepted
          : OrderStatus.requested,
      note: note.trim().isEmpty
          ? 'Bonjour, je souhaite commander / réserver cette offre.'
          : note.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      unreadCount: 1,
    );

    _orders.insert(0, newOrder);

    // Création automatique du fil de discussion lié à la commande
    _messagesByOrder[orderId] = [
      ChatMessage(
        id: 'msg_sys_1',
        orderId: orderId,
        senderId: 'system',
        senderName: 'Système EduLink',
        text: isImmediateFreeDigital
            ? 'Ressource numérique gratuite : commande acceptée automatiquement. Téléchargement débloqué !'
            : selectedSlot != null
                ? 'Créneau verrouillé (${selectedSlot.date} ${selectedSlot.startTime}-${selectedSlot.endTime}). En attente de confirmation du vendeur.'
                : 'Demande de commande envoyée. Le paiement se fait hors application (en main propre ou convenu entre les parties).',
        createdAt: DateTime.now(),
        isSystemMessage: true,
      ),
      ChatMessage(
        id: 'msg_init_2',
        orderId: orderId,
        senderId: currentUserId,
        senderName: currentUserName,
        text: newOrder.note,
        readAt: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    ];

    notifyListeners();
    return newOrder;
  }

  /// Fait évoluer le cycle de vie d'une commande (`PATCH /orders/:id/status`) et applique
  /// les effets de bord associés :
  /// - À l'acceptation (`accepted`) : génère automatiquement la salle Jitsi Meet pour un cours
  ///   en ligne, ou décrémente le stock disponible pour une ressource physique (passage à `soldOut` si stock nul).
  /// - Au refus (`rejected`) ou à l'annulation (`cancelled`) : déverrouille le créneau horaire réservé.
  /// - À la clôture (`completed`) : incrémente le compteur de ventes `salesCount` de l'offre.
  /// Ajoute systématiquement un message système dans la conversation liée avant d'appeler [notifyListeners].
  void updateOrderStatus(String orderId, OrderStatus newStatus) {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;
    final order = _orders[idx];

    // Génération automatique du lien Jitsi Meet à l'acceptation d'un cours en ligne
    String? generatedJitsiLink = order.meetingLink;
    if (newStatus == OrderStatus.accepted &&
        order.offerType == OfferType.privateLesson &&
        order.pickupAddress == null) {
      generatedJitsiLink = 'https://meet.jit.si/edulink-${order.id}';
    }

    // Diminution du stock d'une ressource physique à l'acceptation
    if (newStatus == OrderStatus.accepted &&
        order.offerType == OfferType.resourcePhysical) {
      final oIdx = _offers.indexWhere((o) => o.id == order.offerId);
      if (oIdx != -1) {
        final currentQty = _offers[oIdx].quantity ?? 1;
        final nextQty = (currentQty - order.quantity).clamp(0, 999);
        _offers[oIdx] = _offers[oIdx].copyWith(
          quantity: nextQty,
          status: nextQty == 0 ? OfferStatus.soldOut : _offers[oIdx].status,
        );
      }
    }

    // Libération du créneau en cas de refus ou d'annulation
    if ((newStatus == OrderStatus.rejected ||
            newStatus == OrderStatus.cancelled) &&
        order.slotId != null) {
      final slots = _slotsByOffer[order.offerId];
      if (slots != null) {
        final sIdx = slots.indexWhere((s) => s.id == order.slotId);
        if (sIdx != -1) {
          slots[sIdx] = slots[sIdx].copyWith(isBooked: false, orderId: null);
        }
      }
    }

    // Incrémentation du compteur de ventes lorsque la commande passe à `completed`
    if (newStatus == OrderStatus.completed) {
      final oIdx = _offers.indexWhere((o) => o.id == order.offerId);
      if (oIdx != -1) {
        _offers[oIdx] = _offers[oIdx].copyWith(
          salesCount: _offers[oIdx].salesCount + 1,
        );
      }
    }

    _orders[idx] = order.copyWith(
      status: newStatus,
      meetingLink: generatedJitsiLink,
      updatedAt: DateTime.now(),
    );

    // Ajout d'un message système dans le chat de la commande
    final msgs = _messagesByOrder.putIfAbsent(orderId, () => []);
    String sysText = 'Statut de la commande mis à jour : ${newStatus.label}.';
    if (newStatus == OrderStatus.accepted) {
      if (generatedJitsiLink != null) {
        sysText =
            'Commande acceptée ! Salle Jitsi Meet générée automatiquement : $generatedJitsiLink';
      } else if (order.offerType == OfferType.resourceDigital) {
        sysText =
            'Commande acceptée ! Le fichier privé est maintenant débloqué au téléchargement.';
      } else {
        sysText =
            'Commande acceptée ! Convenez du rendez-vous de remise dans ce chat.';
      }
    } else if (newStatus == OrderStatus.completed) {
      sysText =
          'Commande marquée comme terminée. L\'acheteur peut maintenant laisser un avis (1 à 5 ★).';
    } else if (newStatus == OrderStatus.rejected ||
        newStatus == OrderStatus.cancelled) {
      sysText =
          'Commande ${newStatus.label.toLowerCase()}. Le créneau / stock réservé a été libéré.';
    }

    msgs.add(
      ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        orderId: orderId,
        senderId: 'system',
        senderName: 'Système EduLink',
        text: sysText,
        createdAt: DateTime.now(),
        isSystemMessage: true,
      ),
    );

    notifyListeners();
  }

  /// Ajoute un message utilisateur (avec pièce jointe optionnelle hébergée sur Cloudinary)
  /// dans le fil de discussion de la commande [orderId], puis notifie les écouteurs.
  void sendMessage(String orderId, String text, {String? attachmentLabel}) {
    final list = _messagesByOrder.putIfAbsent(orderId, () => []);
    list.add(
      ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        orderId: orderId,
        senderId: currentUserId,
        senderName: currentUserName,
        text: text,
        attachmentUrl: attachmentLabel != null
            ? 'https://res.cloudinary.com/edulink/upload/$attachmentLabel'
            : null,
        attachmentLabel: attachmentLabel,
        readAt: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    );
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      _orders[idx] = _orders[idx].copyWith(
        updatedAt: DateTime.now(),
        unreadCount: 0,
      );
    }
    notifyListeners();
  }

  /// Réinitialise le compteur `unreadCount` de la commande [orderId] à l'ouverture de l'écran de chat.
  void markConversationRead(String orderId) {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx != -1 && _orders[idx].unreadCount > 0) {
      _orders[idx] = _orders[idx].copyWith(unreadCount: 0);
      notifyListeners();
    }
  }

  /// Enregistre l'évaluation vérifiée d'une commande terminée (`POST /reviews`).
  /// Utilise `order.id` comme identifiant d'avis pour garantir l'unicité par commande,
  /// marque `hasReview: true` et recalcule la moyenne pondérée `ratingAvg` de l'offre.
  void submitReview({
    required MarketplaceOrder order,
    required int rating,
    required String comment,
  }) {
    final oIdx = _orders.indexWhere((o) => o.id == order.id);
    if (oIdx != -1) {
      _orders[oIdx] = _orders[oIdx].copyWith(hasReview: true);
    }

    _reviews.insert(
      0,
      OfferReview(
        id: order.id,
        buyerId: currentUserId,
        buyerName: currentUserName,
        buyerRoleLabel: currentUserRole == SellerRole.teacher
            ? 'Enseignant vérifié'
            : 'Étudiant',
        sellerId: order.sellerId,
        offerId: order.offerId,
        rating: rating,
        comment: comment,
        createdAt: DateTime.now(),
      ),
    );

    // Recalcul de la moyenne des notes sur l'offre
    final offerIdx = _offers.indexWhere((o) => o.id == order.offerId);
    if (offerIdx != -1) {
      final offer = _offers[offerIdx];
      final totalScore = (offer.ratingAvg * offer.ratingCount) + rating;
      final newCount = offer.ratingCount + 1;
      _offers[offerIdx] = offer.copyWith(
        ratingAvg: totalScore / newCount,
        ratingCount: newCount,
      );
    }

    notifyListeners();
  }

  /// Peuple les collections en mémoire avec un jeu de données initial cohérent
  /// (offres publiées et brouillon, créneaux horaires, commandes acheteur/vendeur, avis et messages).
  void _seedInitialData() {
    _offers.addAll([
      Offer(
        id: 'offer_1',
        sellerId: 'seller_amine',
        sellerName: 'Amine Trabelsi',
        sellerAvatar: 'AT',
        sellerSubtitle: 'M1 Génie Logiciel · INSAT Tunis',
        sellerBadges: const ['Vendeur', 'Bien noté'],
        sellerRole: SellerRole.student,
        type: OfferType.resourceDigital,
        title: 'Fiches Algo & Complexité — Résumé + 25 Annales Corrigées',
        subject: 'Algorithmique',
        level: 'L2',
        description:
            'Pack complet de révision en Algorithmique et Structures de Données : arbres AVL, graphes (Dijkstra, Bellman-Ford), programmation dynamique et analyse de complexité amortie. Inclut 25 sujets d\'examens corrigés étape par étape.',
        price: 12,
        fileUrl: 'https://res.cloudinary.com/edulink/private/fiches_algo_l2.pdf',
        fileSizeLabel: 'PDF haute qualité · 6.4 Mo · 54 pages',
        courseId: 'course_algo_1',
        courseTitle: 'Algorithmique & Structures de Données (Chapitres 1–6)',
        status: OfferStatus.published,
        viewsCount: 214,
        salesCount: 38,
        ratingAvg: 4.9,
        ratingCount: 24,
        createdAt: DateTime(2026, 10, 18),
        isRecommendedByCourse: true,
      ),
      Offer(
        id: 'offer_2',
        sellerId: 'seller_pr_salma',
        sellerName: 'Dr. Salma Khelifi',
        sellerAvatar: 'SK',
        sellerSubtitle: 'Maître de Conférences · FST Tunis',
        sellerBadges: const ['Enseignant vérifié', 'Mentor', 'Bien noté'],
        sellerRole: SellerRole.teacher,
        type: OfferType.privateLesson,
        title: 'Cours particulier d\'Algorithmique & Préparation Examen (1 h)',
        subject: 'Algorithmique',
        level: 'L2',
        description:
            'Séance individuelle d\'accompagnement méthodologique sur les algorithmes de graphes, la récursivité et la résolution d\'exercices complexes sur tableau partagé Jitsi Meet.',
        price: 35,
        mode: DeliveryMode.online,
        courseId: 'course_algo_1',
        courseTitle: 'Algorithmique & Structures de Données (Chapitres 1–6)',
        status: OfferStatus.published,
        viewsCount: 168,
        salesCount: 29,
        ratingAvg: 4.95,
        ratingCount: 19,
        createdAt: DateTime(2026, 10, 19),
        isRecommendedByCourse: true,
      ),
      Offer(
        id: 'offer_3',
        sellerId: 'seller_nour',
        sellerName: 'Nour Gharbi',
        sellerAvatar: 'NG',
        sellerSubtitle: 'L3 Informatique · ENSI Manouba',
        sellerBadges: const ['Vendeur'],
        sellerRole: SellerRole.student,
        type: OfferType.resourcePhysical,
        title: 'Livre "Introduction à l\'Algorithmique" (Cormen) + Polycopiés TD',
        subject: 'Algorithmique',
        level: 'L3',
        description:
            'Exemplaire physique en très bon état (aucune page cornée, quelques surlignages propres au crayon) accompagné du recueil imprimé des TD corrigés de l\'ENSI.',
        price: 45,
        condition: OfferCondition.bon,
        quantity: 2,
        mode: DeliveryMode.onsite,
        location: const OfferLocation(
          address: 'Campus Universitaire de la Manouba, devant la bibliothèque ENSI',
          city: 'Manouba',
          lat: 36.8136,
          lng: 10.0637,
        ),
        status: OfferStatus.published,
        viewsCount: 95,
        salesCount: 4,
        ratingAvg: 4.7,
        ratingCount: 6,
        createdAt: DateTime(2026, 10, 20),
      ),
      Offer(
        id: 'offer_4',
        sellerId: 'seller_pr_mehdi',
        sellerName: 'Pr. Mehdi Bouazizi',
        sellerAvatar: 'MB',
        sellerSubtitle: 'Enseignant Chercheur · Sup\'Com Ariana',
        sellerBadges: const ['Enseignant vérifié', 'Bien noté'],
        sellerRole: SellerRole.teacher,
        type: OfferType.resourceDigital,
        title: 'Aide-mémoire SQL, Indexation Firestore & Normalisation (3NF/BCNF)',
        subject: 'Bases de Données',
        level: 'L3',
        description:
            'Support synthétique gratuit couvrant l\'optimisation des requêtes SQL, la conception de schémas NoSQL (collections, sous-collections et index composites Firestore) et des cas pratiques.',
        price: 0,
        fileUrl: 'https://res.cloudinary.com/edulink/private/sql_firestore_sheet.pdf',
        fileSizeLabel: 'PDF · 2.1 Mo · 18 pages',
        courseId: 'course_bdd_2',
        courseTitle: 'Bases de Données Relationnelles & SQL Avancé',
        status: OfferStatus.published,
        viewsCount: 342,
        salesCount: 91,
        ratingAvg: 4.85,
        ratingCount: 42,
        createdAt: DateTime(2026, 10, 21),
        isRecommendedByCourse: true,
      ),
      Offer(
        id: 'offer_5',
        sellerId: 'seller_rami',
        sellerName: 'Rami Jaziri',
        sellerAvatar: 'RJ',
        sellerSubtitle: 'M2 Data Science · ISI Ariana',
        sellerBadges: const ['Mentor', 'Vendeur'],
        sellerRole: SellerRole.student,
        type: OfferType.privateLesson,
        title: 'Coaching Projet Flutter & NestJS / Architecture Clean (1 h)',
        subject: 'Développement Mobile',
        level: 'L3',
        description:
            'Accompagnement pratique en présentiel ou en ligne sur vos projets Flutter (Provider, gestion d\'état, consommation d\'API REST NestJS et règles Firebase).',
        price: 25,
        mode: DeliveryMode.onsite,
        location: const OfferLocation(
          address: 'Espace Coworking Technopôle El Ghazala, Ariana',
          city: 'Ariana',
          lat: 36.8927,
          lng: 10.1874,
        ),
        courseId: 'course_flutter_4',
        courseTitle: 'Architecture Mobile Cross-Platform (Flutter & NestJS)',
        status: OfferStatus.published,
        viewsCount: 118,
        salesCount: 14,
        ratingAvg: 4.8,
        ratingCount: 11,
        createdAt: DateTime(2026, 10, 22),
      ),
      // Offres appartenant à l'utilisateur connecté ("Mes offres")
      Offer(
        id: 'offer_me_1',
        sellerId: 'user_me',
        sellerName: 'Yasmine Ben Ali',
        sellerAvatar: 'YB',
        sellerSubtitle: 'L3 Génie Logiciel · FST Tunis',
        sellerBadges: const ['Vendeur', 'Mentor', 'Bien noté'],
        sellerRole: SellerRole.student,
        type: OfferType.resourceDigital,
        title: 'Fiches de Révision Réseaux TCP/IP, Modèle OSI & Sous-réseaux',
        subject: 'Réseaux & Sécurité',
        level: 'L2',
        description:
            'Fiches illustrées avec exercices de découpage VLSM/CIDR, analyse de trames Wireshark et protocole de routage OSPF.',
        price: 10,
        fileUrl: 'https://res.cloudinary.com/edulink/private/fiches_reseaux_vlsm.pdf',
        fileSizeLabel: 'PDF · 3.8 Mo · 32 pages',
        status: OfferStatus.published,
        viewsCount: 146,
        salesCount: 19,
        ratingAvg: 4.75,
        ratingCount: 12,
        createdAt: DateTime(2026, 10, 16),
      ),
      Offer(
        id: 'offer_me_2',
        sellerId: 'user_me',
        sellerName: 'Yasmine Ben Ali',
        sellerAvatar: 'YB',
        sellerSubtitle: 'L3 Génie Logiciel · FST Tunis',
        sellerBadges: const ['Vendeur', 'Mentor', 'Bien noté'],
        sellerRole: SellerRole.student,
        type: OfferType.privateLesson,
        title: 'Soutien Mathématiques Discrètes & Logique Formelle (1 h)',
        subject: 'Mathématiques',
        level: 'L1',
        description:
            'Cours particulier individuel en ligne via Jitsi Meet pour préparer les DS et examens de logique, théorie des ensembles et dénombrement.',
        price: 20,
        mode: DeliveryMode.online,
        status: OfferStatus.published,
        viewsCount: 89,
        salesCount: 8,
        ratingAvg: 4.9,
        ratingCount: 8,
        createdAt: DateTime(2026, 10, 17),
      ),
      Offer(
        id: 'offer_me_3',
        sellerId: 'user_me',
        sellerName: 'Yasmine Ben Ali',
        sellerAvatar: 'YB',
        sellerSubtitle: 'L3 Génie Logiciel · FST Tunis',
        sellerBadges: const ['Vendeur', 'Mentor', 'Bien noté'],
        sellerRole: SellerRole.student,
        type: OfferType.resourcePhysical,
        title: 'Calculatrice Graphique Casio fx-92 + Annales Imprimées',
        subject: 'Mathématiques',
        level: 'L1',
        description:
            'Calculatrice scientifique autorisée aux examens universitaires, état neuf avec étui de protection.',
        price: 30,
        condition: OfferCondition.neuf,
        quantity: 1,
        mode: DeliveryMode.onsite,
        location: const OfferLocation(
          address: 'Campus FST El Manar, Tunis',
          city: 'Tunis',
          lat: 36.8325,
          lng: 10.1469,
        ),
        status: OfferStatus.draft,
        viewsCount: 0,
        salesCount: 0,
        ratingAvg: 0,
        ratingCount: 0,
        createdAt: DateTime(2026, 10, 24),
      ),
    ]);

    // Créneaux horaires rattachés aux offres de cours particuliers
    _slotsByOffer['offer_2'] = [
      const AvailabilitySlot(
        id: 'slot_201',
        offerId: 'offer_2',
        sellerId: 'seller_pr_salma',
        date: 'Lun 26 Oct 2026',
        startTime: '17:00',
        endTime: '18:00',
      ),
      const AvailabilitySlot(
        id: 'slot_202',
        offerId: 'offer_2',
        sellerId: 'seller_pr_salma',
        date: 'Mar 27 Oct 2026',
        startTime: '18:30',
        endTime: '19:30',
        isBooked: true,
        orderId: 'ord_demo_1',
      ),
      const AvailabilitySlot(
        id: 'slot_203',
        offerId: 'offer_2',
        sellerId: 'seller_pr_salma',
        date: 'Jeu 29 Oct 2026',
        startTime: '15:00',
        endTime: '16:00',
      ),
      const AvailabilitySlot(
        id: 'slot_204',
        offerId: 'offer_2',
        sellerId: 'seller_pr_salma',
        date: 'Sam 31 Oct 2026',
        startTime: '10:00',
        endTime: '11:00',
      ),
    ];

    _slotsByOffer['offer_5'] = [
      const AvailabilitySlot(
        id: 'slot_501',
        offerId: 'offer_5',
        sellerId: 'seller_rami',
        date: 'Mer 28 Oct 2026',
        startTime: '14:00',
        endTime: '15:00',
      ),
      const AvailabilitySlot(
        id: 'slot_502',
        offerId: 'offer_5',
        sellerId: 'seller_rami',
        date: 'Ven 30 Oct 2026',
        startTime: '16:00',
        endTime: '17:00',
      ),
    ];

    _slotsByOffer['offer_me_2'] = [
      const AvailabilitySlot(
        id: 'slot_me_1',
        offerId: 'offer_me_2',
        sellerId: 'user_me',
        date: 'Mar 27 Oct 2026',
        startTime: '16:00',
        endTime: '17:00',
        isBooked: true,
        orderId: 'ord_seller_1',
      ),
      const AvailabilitySlot(
        id: 'slot_me_2',
        offerId: 'offer_me_2',
        sellerId: 'user_me',
        date: 'Jeu 29 Oct 2026',
        startTime: '17:30',
        endTime: '18:30',
      ),
    ];

    // Commandes simulées côté Acheteur ("Mes achats") et côté Vendeur ("Demandes reçues")
    _orders.addAll([
      MarketplaceOrder(
        id: 'ord_demo_1',
        offerId: 'offer_2',
        offerTitle: 'Cours particulier d\'Algorithmique & Préparation Examen (1 h)',
        offerType: OfferType.privateLesson,
        offerSubject: 'Algorithmique',
        buyerId: 'user_me',
        buyerName: 'Yasmine Ben Ali',
        sellerId: 'seller_pr_salma',
        sellerName: 'Dr. Salma Khelifi',
        sellerRole: SellerRole.teacher,
        amount: 35,
        slotId: 'slot_202',
        slotLabel: 'Mar 27 Oct 2026 · 18:30 - 19:30',
        meetingLink: 'https://meet.jit.si/edulink-ord_demo_1',
        status: OrderStatus.accepted,
        note: 'Bonjour Madame, j\'aimerais revoir l\'algorithme de Dijkstra et les arbres équilibrés.',
        createdAt: DateTime(2026, 10, 24, 14, 15),
        updatedAt: DateTime(2026, 10, 24, 15, 00),
        unreadCount: 1,
      ),
      MarketplaceOrder(
        id: 'ord_demo_2',
        offerId: 'offer_1',
        offerTitle: 'Fiches Algo & Complexité — Résumé + 25 Annales Corrigées',
        offerType: OfferType.resourceDigital,
        offerSubject: 'Algorithmique',
        buyerId: 'user_me',
        buyerName: 'Yasmine Ben Ali',
        sellerId: 'seller_amine',
        sellerName: 'Amine Trabelsi',
        sellerRole: SellerRole.student,
        amount: 12,
        fileUrl: 'https://res.cloudinary.com/edulink/private/fiches_algo_l2.pdf',
        status: OrderStatus.completed,
        note: 'Je te règle les 12 TND demain matin devant le département Info !',
        createdAt: DateTime(2026, 10, 21, 10, 30),
        updatedAt: DateTime(2026, 10, 22, 11, 20),
        unreadCount: 0,
        hasReview: false,
      ),
      MarketplaceOrder(
        id: 'ord_seller_1',
        offerId: 'offer_me_2',
        offerTitle: 'Soutien Mathématiques Discrètes & Logique Formelle (1 h)',
        offerType: OfferType.privateLesson,
        offerSubject: 'Mathématiques',
        buyerId: 'buyer_skander',
        buyerName: 'Skander Haddad',
        sellerId: 'user_me',
        sellerName: 'Yasmine Ben Ali',
        sellerRole: SellerRole.student,
        amount: 20,
        slotId: 'slot_me_1',
        slotLabel: 'Mar 27 Oct 2026 · 16:00 - 17:00',
        status: OrderStatus.requested,
        note: 'Salut Yasmine ! Est-ce qu\'on pourra traiter le sujet de DS 2025 sur la récurrence ?',
        createdAt: DateTime(2026, 10, 25, 11, 10),
        updatedAt: DateTime(2026, 10, 25, 11, 10),
        unreadCount: 2,
      ),
      MarketplaceOrder(
        id: 'ord_seller_2',
        offerId: 'offer_me_1',
        offerTitle: 'Fiches de Révision Réseaux TCP/IP, Modèle OSI & Sous-réseaux',
        offerType: OfferType.resourceDigital,
        offerSubject: 'Réseaux & Sécurité',
        buyerId: 'buyer_ines',
        buyerName: 'Inès Chaabane',
        sellerId: 'user_me',
        sellerName: 'Yasmine Ben Ali',
        sellerRole: SellerRole.student,
        amount: 10,
        fileUrl: 'https://res.cloudinary.com/edulink/private/fiches_reseaux_vlsm.pdf',
        status: OrderStatus.accepted,
        note: 'Merci beaucoup, je passe à la pause de 13h pour le règlement hors-app.',
        createdAt: DateTime(2026, 10, 24, 09, 40),
        updatedAt: DateTime(2026, 10, 24, 10, 05),
        unreadCount: 0,
      ),
    ]);

    // Avis vérifiés initiaux associés aux offres du catalogue
    _reviews.addAll([
      OfferReview(
        id: 'rev_101',
        buyerId: 'buyer_1',
        buyerName: 'Mehdi Oueslati',
        buyerRoleLabel: 'Étudiant · L2 Info',
        sellerId: 'seller_amine',
        offerId: 'offer_1',
        rating: 5,
        comment:
            'Les fiches sont hyper claires et les corrections détaillées m\'ont permis d\'avoir 16.5/20 au partiel d\'Algo !',
        createdAt: DateTime(2026, 10, 20),
      ),
      OfferReview(
        id: 'rev_102',
        buyerId: 'buyer_2',
        buyerName: 'Sarra Miled',
        buyerRoleLabel: 'Étudiante · L2 GL',
        sellerId: 'seller_amine',
        offerId: 'offer_1',
        rating: 5,
        comment:
            'Les schémas sur les rotations d\'arbres AVL et Dijkstra sont top. Je recommande à 100%.',
        createdAt: DateTime(2026, 10, 22),
      ),
      OfferReview(
        id: 'rev_201',
        buyerId: 'buyer_3',
        buyerName: 'Fares Zouari',
        buyerRoleLabel: 'Étudiant · L2 Info',
        sellerId: 'seller_pr_salma',
        offerId: 'offer_2',
        rating: 5,
        comment:
            'Explications très pédagogiques ! En 1h sur Jitsi j\'ai enfin compris la programmation dynamique.',
        createdAt: DateTime(2026, 10, 23),
      ),
    ]);

    // Historiques initiaux des conversations liées aux commandes en cours
    _messagesByOrder['ord_demo_1'] = [
      ChatMessage(
        id: 'm1',
        orderId: 'ord_demo_1',
        senderId: 'system',
        senderName: 'Système EduLink',
        text: 'Créneau verrouillé (Mar 27 Oct 2026 · 18:30 - 19:30).',
        createdAt: DateTime(2026, 10, 24, 14, 15),
        isSystemMessage: true,
      ),
      ChatMessage(
        id: 'm2',
        orderId: 'ord_demo_1',
        senderId: 'user_me',
        senderName: 'Yasmine Ben Ali',
        text:
            'Bonjour Madame, j\'aimerais revoir l\'algorithme de Dijkstra et les arbres équilibrés.',
        readAt: DateTime(2026, 10, 24, 14, 50),
        createdAt: DateTime(2026, 10, 24, 14, 16),
      ),
      ChatMessage(
        id: 'm3',
        orderId: 'ord_demo_1',
        senderId: 'system',
        senderName: 'Système EduLink',
        text:
            'Commande acceptée ! Salle Jitsi Meet générée : https://meet.jit.si/edulink-ord_demo_1',
        createdAt: DateTime(2026, 10, 24, 15, 00),
        isSystemMessage: true,
      ),
      ChatMessage(
        id: 'm4',
        orderId: 'ord_demo_1',
        senderId: 'seller_pr_salma',
        senderName: 'Dr. Salma Khelifi',
        text:
            'Bonjour Yasmine ! C\'est noté, je vous ai préparé la série d\'exercices corrigés en pièce jointe pour mardi.',
        attachmentUrl: 'https://res.cloudinary.com/edulink/upload/serie_graphes_avl.pdf',
        attachmentLabel: 'serie_graphes_avl.pdf',
        createdAt: DateTime(2026, 10, 24, 15, 02),
      ),
    ];

    _messagesByOrder['ord_seller_1'] = [
      ChatMessage(
        id: 'ms1',
        orderId: 'ord_seller_1',
        senderId: 'system',
        senderName: 'Système EduLink',
        text: 'Nouvelle demande de réservation pour le créneau Mar 27 Oct 2026 · 16:00 - 17:00.',
        createdAt: DateTime(2026, 10, 25, 11, 10),
        isSystemMessage: true,
      ),
      ChatMessage(
        id: 'ms2',
        orderId: 'ord_seller_1',
        senderId: 'buyer_skander',
        senderName: 'Skander Haddad',
        text:
            'Salut Yasmine ! Est-ce qu\'on pourra traiter le sujet de DS 2025 sur la récurrence ?',
        createdAt: DateTime(2026, 10, 25, 11, 11),
      ),
      ChatMessage(
        id: 'ms3',
        orderId: 'ord_seller_1',
        senderId: 'buyer_skander',
        senderName: 'Skander Haddad',
        text: 'Je t\'envoie l\'énoncé du DS en pièce jointe.',
        attachmentUrl: 'https://res.cloudinary.com/edulink/upload/ds_logique_2025.pdf',
        attachmentLabel: 'ds_logique_2025.pdf',
        createdAt: DateTime(2026, 10, 25, 11, 12),
      ),
    ];
  }
}
