import 'package:flutter/material.dart';

// Modèles de données immuables de la Marketplace EduLink.
// Structure alignée sur les collections Firestore :
// - offers : ressources numériques, ressources physiques et cours particuliers
// - availabilities : créneaux horaires rattachés aux cours particuliers
// - orders : commandes et réservations entre acheteurs et vendeurs
// - reviews : avis vérifiés (identifiant du document égal à orderId)
// - favorites & reports : favoris utilisateurs et signalements de modération
// - conversations & conversations/{id}/messages : messagerie temps réel par commande

/// Catégories d'offres prises en charge dans le catalogue :
/// - [resourceDigital] (`resource_digital`) : supports numériques PDF (fiches, annales corrigées)
/// - [resourcePhysical] (`resource_physical`) : ouvrages ou matériel académique d'occasion
/// - [privateLesson] (`private_lesson`) : séance individuelle d'une heure (en ligne via Jitsi ou en présentiel)
enum OfferType {
  resourceDigital,
  resourcePhysical,
  privateLesson;

  /// Identifiant technique stocké dans Firestore (`offers.type`)
  String get code {
    switch (this) {
      case OfferType.resourceDigital:
        return 'resource_digital';
      case OfferType.resourcePhysical:
        return 'resource_physical';
      case OfferType.privateLesson:
        return 'private_lesson';
    }
  }

  /// Libellé complet affiché dans l'interface utilisateur
  String get label {
    switch (this) {
      case OfferType.resourceDigital:
        return 'Ressource numérique';
      case OfferType.resourcePhysical:
        return 'Ressource physique';
      case OfferType.privateLesson:
        return 'Cours particulier';
    }
  }

  /// Libellé court utilisé sur les badges des cartes d'offres
  String get shortLabel {
    switch (this) {
      case OfferType.resourceDigital:
        return 'Numérique (PDF)';
      case OfferType.resourcePhysical:
        return 'Physique';
      case OfferType.privateLesson:
        return 'Cours 1h';
    }
  }

  /// Icône associée au type d'offre
  IconData get icon {
    switch (this) {
      case OfferType.resourceDigital:
        return Icons.picture_as_pdf_rounded;
      case OfferType.resourcePhysical:
        return Icons.menu_book_rounded;
      case OfferType.privateLesson:
        return Icons.co_present_rounded;
    }
  }

  /// Couleur distinctive associée au type d'offre
  Color get color {
    switch (this) {
      case OfferType.resourceDigital:
        return const Color(0xFF2563EB);
      case OfferType.resourcePhysical:
        return const Color(0xFFD97706);
      case OfferType.privateLesson:
        return const Color(0xFF7C3AED);
    }
  }
}

/// Profil d'origine du vendeur (`offers.sellerRole`) permettant de distinguer
/// visuellement une publication étudiante d'une publication d'enseignant vérifié.
enum SellerRole {
  student,
  teacher;

  /// Texte du badge affiché sur chaque carte et page de détail d'offre
  String get badgeLabel {
    switch (this) {
      case SellerRole.student:
        return 'Offre étudiant';
      case SellerRole.teacher:
        return 'Enseignant vérifié';
    }
  }
}

/// État d'usure d'une ressource physique (`offers.condition` : neuf | bon | usagé)
enum OfferCondition {
  neuf,
  bon,
  usage;

  String get label {
    switch (this) {
      case OfferCondition.neuf:
        return 'Neuf';
      case OfferCondition.bon:
        return 'Bon état';
      case OfferCondition.usage:
        return 'Usagé';
    }
  }
}

/// Modalité d'un cours particulier ou d'une remise (`offers.mode` : online | onsite)
enum DeliveryMode {
  online,
  onsite;

  String get label {
    switch (this) {
      case DeliveryMode.online:
        return 'En ligne (Jitsi)';
      case DeliveryMode.onsite:
        return 'En présentiel';
    }
  }
}

/// Cycle de vie d'une offre dans le catalogue (`draft`, `published`, `sold_out`, `hidden`).
/// Une offre publiée bascule automatiquement vers [hidden] lorsqu'elle cumule 3 signalements.
enum OfferStatus {
  draft,
  published,
  soldOut,
  hidden;

  String get label {
    switch (this) {
      case OfferStatus.draft:
        return 'Brouillon';
      case OfferStatus.published:
        return 'Publiée';
      case OfferStatus.soldOut:
        return 'Épuisée';
      case OfferStatus.hidden:
        return 'Masquée';
    }
  }

  Color get color {
    switch (this) {
      case OfferStatus.draft:
        return const Color(0xFF64748B);
      case OfferStatus.published:
        return const Color(0xFF16A34A);
      case OfferStatus.soldOut:
        return const Color(0xFFDC2626);
      case OfferStatus.hidden:
        return const Color(0xFFD97706);
    }
  }
}

/// États successifs d'une commande ou réservation (`orders.status`) :
/// - [requested] : demande envoyée par l'acheteur (verrouille le créneau choisi le cas échéant)
/// - [accepted] : confirmée par le vendeur (débloque le PDF privé, décrémente le stock ou génère le lien Jitsi)
/// - [completed] : remise ou séance effectuée (autorise le dépôt d'un unique avis noté de 1 à 5 étoiles)
/// - [rejected] : déclinée par le vendeur (libère automatiquement le créneau réservé)
/// - [cancelled] : annulée par l'acheteur avant acceptation (libère le créneau réservé)
enum OrderStatus {
  requested,
  accepted,
  completed,
  rejected,
  cancelled;

  String get label {
    switch (this) {
      case OrderStatus.requested:
        return 'En attente';
      case OrderStatus.accepted:
        return 'Acceptée';
      case OrderStatus.completed:
        return 'Terminée';
      case OrderStatus.rejected:
        return 'Refusée';
      case OrderStatus.cancelled:
        return 'Annulée';
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.requested:
        return const Color(0xFFD97706);
      case OrderStatus.accepted:
        return const Color(0xFF2563EB);
      case OrderStatus.completed:
        return const Color(0xFF16A34A);
      case OrderStatus.rejected:
        return const Color(0xFFDC2626);
      case OrderStatus.cancelled:
        return const Color(0xFF64748B);
    }
  }

  IconData get icon {
    switch (this) {
      case OrderStatus.requested:
        return Icons.schedule_rounded;
      case OrderStatus.accepted:
        return Icons.check_circle_outline_rounded;
      case OrderStatus.completed:
        return Icons.task_alt_rounded;
      case OrderStatus.rejected:
        return Icons.cancel_outlined;
      case OrderStatus.cancelled:
        return Icons.block_rounded;
    }
  }
}

/// Adresse postale et coordonnées GPS (`lat`, `lng`) d'un lieu de remise ou de cours en présentiel,
/// résolues via le service de géocodage OpenStreetMap Nominatim.
class OfferLocation {
  final String address;
  final String city;
  final double lat;
  final double lng;

  const OfferLocation({
    required this.address,
    required this.city,
    required this.lat,
    required this.lng,
  });
}

/// Créneau horaire d'une heure rattaché à une offre de cours particulier (`availabilities`).
/// Lors d'une réservation, [isBooked] passe à `true` et [orderId] conserve la référence de la commande.
class AvailabilitySlot {
  final String id;
  final String offerId;
  final String sellerId;
  final String date; // Exemple : "Lun 26 Oct 2026"
  final String startTime; // Exemple : "17:00"
  final String endTime; // Exemple : "18:00"
  final bool isBooked; // Verrouillé par transaction Firestore si réservé
  final String? orderId; // Identifiant de la commande qui a réservé ce créneau

  const AvailabilitySlot({
    required this.id,
    required this.offerId,
    required this.sellerId,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.isBooked = false,
    this.orderId,
  });

  /// Retourne une copie modifiée du créneau (ex. lors du verrouillage/déverrouillage)
  AvailabilitySlot copyWith({
    bool? isBooked,
    String? orderId,
  }) {
    return AvailabilitySlot(
      id: id,
      offerId: offerId,
      sellerId: sellerId,
      date: date,
      startTime: startTime,
      endTime: endTime,
      isBooked: isBooked ?? this.isBooked,
      orderId: orderId ?? this.orderId,
    );
  }
}

/// Entité immuable représentant une offre publiée ou en brouillon (`offers`).
class Offer {
  final String id;
  final String sellerId;
  final String sellerName;
  final String sellerAvatar;
  final String sellerSubtitle; // Filière/établissement (étudiant) ou grade académique (enseignant)
  final List<String> sellerBadges; // Badges d'activité obtenus par le vendeur
  final SellerRole sellerRole; // student | teacher
  final OfferType type; // resource_digital | resource_physical | private_lesson
  final String title;
  final String subject;
  final String level;
  final String description;
  final List<String> images; // URLs des photos d'illustration hébergées sur Cloudinary
  final double price; // Prix en TND (0 = gratuit)
  final String? fileUrl; // URL privée Cloudinary (uniquement pour resource_digital)
  final String? fileSizeLabel; // Métadonnées affichées pour le fichier PDF
  final OfferCondition? condition; // État neuf | bon | usagé (pour resource_physical)
  final int? quantity; // Stock disponible (pour resource_physical)
  final DeliveryMode? mode; // online (Jitsi) | onsite (présentiel)
  final OfferLocation? location; // Adresse et coordonnées OpenStreetMap Nominatim
  final String? courseId; // Identifiant du cours rattaché (nullable)
  final String? courseTitle; // Titre du cours rattaché (affiché sur la carte et le détail)
  final OfferStatus status; // draft | published | sold_out | hidden
  final int viewsCount; // Incrémenté à chaque lecture GET /offers/:id
  final int salesCount; // Incrémenté à chaque commande terminée
  final double ratingAvg; // Moyenne des notes (1 à 5 ★)
  final int ratingCount; // Nombre total d'avis reçus
  final int reportsCount; // Compteur de signalements (masquée auto à 3)
  final DateTime createdAt;
  final bool isRecommendedByCourse; // Indique si l'offre est recommandée via un cours suivi

  const Offer({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.sellerAvatar,
    required this.sellerSubtitle,
    this.sellerBadges = const [],
    required this.sellerRole,
    required this.type,
    required this.title,
    required this.subject,
    required this.level,
    required this.description,
    this.images = const [],
    required this.price,
    this.fileUrl,
    this.fileSizeLabel,
    this.condition,
    this.quantity,
    this.mode,
    this.location,
    this.courseId,
    this.courseTitle,
    this.status = OfferStatus.published,
    this.viewsCount = 0,
    this.salesCount = 0,
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    this.reportsCount = 0,
    required this.createdAt,
    this.isRecommendedByCourse = false,
  });

  /// Indique si l'offre est gratuite (`price == 0`)
  bool get isFree => price <= 0;

  /// Formate le prix en Dinars Tunisiens (`TND`, `TND / h` pour un cours, ou `Gratuit`)
  String get formattedPrice {
    if (isFree) return 'Gratuit';
    final priceStr = price == price.roundToDouble()
        ? price.toInt().toString()
        : price.toStringAsFixed(1);
    return type == OfferType.privateLesson ? '$priceStr TND / h' : '$priceStr TND';
  }

  /// Crée une copie de l'offre avec les champs mis à jour (statut, vues, ventes, note, signalements...)
  Offer copyWith({
    String? title,
    String? subject,
    String? level,
    String? description,
    double? price,
    OfferCondition? condition,
    int? quantity,
    DeliveryMode? mode,
    OfferLocation? location,
    String? courseId,
    String? courseTitle,
    OfferStatus? status,
    int? viewsCount,
    int? salesCount,
    double? ratingAvg,
    int? ratingCount,
    int? reportsCount,
  }) {
    return Offer(
      id: id,
      sellerId: sellerId,
      sellerName: sellerName,
      sellerAvatar: sellerAvatar,
      sellerSubtitle: sellerSubtitle,
      sellerBadges: sellerBadges,
      sellerRole: sellerRole,
      type: type,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      level: level ?? this.level,
      description: description ?? this.description,
      images: images,
      price: price ?? this.price,
      fileUrl: fileUrl,
      fileSizeLabel: fileSizeLabel,
      condition: condition ?? this.condition,
      quantity: quantity ?? this.quantity,
      mode: mode ?? this.mode,
      location: location ?? this.location,
      courseId: courseId ?? this.courseId,
      courseTitle: courseTitle ?? this.courseTitle,
      status: status ?? this.status,
      viewsCount: viewsCount ?? this.viewsCount,
      salesCount: salesCount ?? this.salesCount,
      ratingAvg: ratingAvg ?? this.ratingAvg,
      ratingCount: ratingCount ?? this.ratingCount,
      reportsCount: reportsCount ?? this.reportsCount,
      createdAt: createdAt,
      isRecommendedByCourse: isRecommendedByCourse,
    );
  }
}

/// Entité immuable représentant une commande de ressource ou une réservation de créneau (`orders`).
class MarketplaceOrder {
  final String id;
  final String offerId;
  final String offerTitle;
  final OfferType offerType;
  final String offerSubject;
  final String buyerId;
  final String buyerName;
  final String sellerId;
  final String sellerName;
  final SellerRole sellerRole;
  final int quantity; // Quantité commandée (pour resource_physical)
  final double amount; // Montant total en TND (réglé hors application)
  final String? slotId; // Référence au créneau réservé (pour private_lesson)
  final String? slotLabel; // Libellé lisible du créneau réservé
  final String? meetingLink; // Lien de visio Jitsi Meet généré à l'acceptation
  final String? pickupAddress; // Adresse de remise en main propre ou cours présentiel
  final String? fileUrl; // Lien de téléchargement débloqué après acceptation
  final OrderStatus status; // requested | accepted | completed | rejected | cancelled
  final String note; // Message initial de l'acheteur
  final DateTime createdAt;
  final DateTime updatedAt;
  final int unreadCount; // Compteur de messages non-lus dans le chat de la commande
  final bool hasReview; // Indique si l'acheteur a déjà laissé son unique avis (id = orderId)

  const MarketplaceOrder({
    required this.id,
    required this.offerId,
    required this.offerTitle,
    required this.offerType,
    required this.offerSubject,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.sellerName,
    required this.sellerRole,
    this.quantity = 1,
    required this.amount,
    this.slotId,
    this.slotLabel,
    this.meetingLink,
    this.pickupAddress,
    this.fileUrl,
    required this.status,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
    this.unreadCount = 0,
    this.hasReview = false,
  });

  /// Retourne une nouvelle instance de [MarketplaceOrder] avec les propriétés modifiées.
  MarketplaceOrder copyWith({
    OrderStatus? status,
    String? meetingLink,
    DateTime? updatedAt,
    int? unreadCount,
    bool? hasReview,
  }) {
    return MarketplaceOrder(
      id: id,
      offerId: offerId,
      offerTitle: offerTitle,
      offerType: offerType,
      offerSubject: offerSubject,
      buyerId: buyerId,
      buyerName: buyerName,
      sellerId: sellerId,
      sellerName: sellerName,
      sellerRole: sellerRole,
      quantity: quantity,
      amount: amount,
      slotId: slotId,
      slotLabel: slotLabel,
      meetingLink: meetingLink ?? this.meetingLink,
      pickupAddress: pickupAddress,
      fileUrl: fileUrl,
      status: status ?? this.status,
      note: note,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      unreadCount: unreadCount ?? this.unreadCount,
      hasReview: hasReview ?? this.hasReview,
    );
  }
}

/// Évaluation vérifiée déposée par l'acheteur une fois la commande terminée (`reviews`).
/// L'identifiant [id] reprend `orderId` afin d'imposer un seul avis par transaction.
class OfferReview {
  final String id; // = orderId (unicité garantie)
  final String buyerId;
  final String buyerName;
  final String buyerRoleLabel;
  final String sellerId;
  final String offerId;
  final int rating; // Note de 1 à 5 étoiles ★
  final String comment;
  final DateTime createdAt;

  const OfferReview({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.buyerRoleLabel,
    required this.sellerId,
    required this.offerId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });
}

/// Message échangé dans le fil de discussion associé à une commande (`conversations/{orderId}/messages`).
/// Peut représenter un message utilisateur ou une notification automatique de suivi ([isSystemMessage]).
class ChatMessage {
  final String id;
  final String orderId;
  final String senderId;
  final String senderName;
  final String text;
  final String? attachmentUrl; // URL de la pièce jointe stockée sur Cloudinary
  final String? attachmentLabel;
  final DateTime? readAt; // Horodatage de lecture du message
  final DateTime createdAt;
  final bool isSystemMessage; // Message automatique de suivi de commande (créneau, Jitsi, statut)

  const ChatMessage({
    required this.id,
    required this.orderId,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.attachmentUrl,
    this.attachmentLabel,
    this.readAt,
    required this.createdAt,
    this.isSystemMessage = false,
  });
}
