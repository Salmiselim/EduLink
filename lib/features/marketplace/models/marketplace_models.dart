// `package:flutter/material.dart` est importé ici uniquement pour les types `Color` et `IconData`
// associés aux énumérations (`OfferType`, `OfferStatus`, `OrderStatus`), ce qui centralise
// la charte graphique (couleurs et icônes par type/statut) directement sur les modèles typés.
import 'package:flutter/material.dart';

// ============================================================================
// MODÈLES DE DONNÉES — MODULE M5 : MARKETPLACE (Pages 7 et 8 du Plan d'équipe)
//
// Architecture de liaison :
// - Immuabilité : toutes les classes (`Offer`, `AvailabilitySlot`, `MarketplaceOrder`,
//   `OfferReview`, `ChatMessage`, `OfferLocation`) utilisent des attributs `final`
//   et exposent une méthode `copyWith(...)` pour créer une copie mise à jour sans effet de bord.
// - Correspondance exacte avec les collections Firestore du schéma :
//   * `Offer`            <-> collection `offers`
//   * `AvailabilitySlot` <-> collection `availabilities`
//   * `MarketplaceOrder` <-> collection `orders`
//   * `OfferReview`      <-> collection `reviews` (avec `id = orderId`)
//   * `ChatMessage`      <-> sous-collection `conversations/{orderId}/messages`
// ============================================================================

/// Les 3 types d'offres autorisés dans la Marketplace (Page 7) :
/// - [resourceDigital] (`resource_digital`) : ex. Fiches PDF, annales corrigées
/// - [resourcePhysical] (`resource_physical`) : ex. Livre d'occasion, polycopié, calculatrice
/// - [privateLesson] (`private_lesson`) : ex. Cours particulier d'1 heure (en ligne Jitsi ou présentiel)
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

/// Rôle du vendeur (`offers.sellerRole`) — Implémente la Règle 5 (Page 2) :
/// Chaque offre affiche l'origine du vendeur : « Offre étudiant » ou « Enseignant vérifié ».
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

/// Statut du cycle de vie d'une offre (`offers.status` : draft | published | sold_out | hidden)
/// Note : Une offre passe automatiquement à `hidden` à partir de 3 signalements (Page 8).
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

/// Statut du parcours d'une commande (`orders.status`, Page 7-8) :
/// 1. [requested] : créée par l'acheteur (créneau verrouillé par transaction Firestore)
/// 2. [accepted] : acceptée par le vendeur (PDF débloqué, stock diminué, ou lien Jitsi généré)
/// 3. [completed] : terminée après remise/séance (ouvre le droit de laisser un avis 1-5 ★)
/// 4. [rejected] : refusée par le vendeur (libère le créneau et le stock)
/// 5. [cancelled] : annulée par l'acheteur avant acceptation (libère le créneau et le stock)
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

/// Coordonnées géographiques et adresse d'une offre (`offers.location {address, lat, lng}`)
/// Résolues via l'API externe gratuite OpenStreetMap Nominatim (Page 8).
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

/// Créneau de disponibilité d'un cours particulier (Collection Firestore `availabilities`, Page 7).
/// Lorsqu'un acheteur réserve ce créneau, [isBooked] passe à `true` et [orderId] est renseigné.
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

/// Modèle principal d'une Offre de la Marketplace (Collection Firestore `offers`, Page 7).
class Offer {
  final String id;
  final String sellerId;
  final String sellerName;
  final String sellerAvatar;
  final String sellerSubtitle; // Université / Filière (étudiant) ou Titre (enseignant)
  final List<String> sellerBadges; // Badges M5 : Vendeur, Mentor, Bien noté (Liaison L9)
  final SellerRole sellerRole; // student | teacher
  final OfferType type; // resource_digital | resource_physical | private_lesson
  final String title;
  final String subject;
  final String level;
  final String description;
  final List<String> images; // URLs Cloudinary (MediaService L10)
  final double price; // Prix en TND (0 = gratuit)
  final String? fileUrl; // URL privée Cloudinary (uniquement pour resource_digital)
  final String? fileSizeLabel; // Métadonnées affichées pour le fichier PDF
  final OfferCondition? condition; // État neuf | bon | usagé (pour resource_physical)
  final int? quantity; // Stock disponible (pour resource_physical)
  final DeliveryMode? mode; // online (Jitsi) | onsite (présentiel)
  final OfferLocation? location; // Adresse et coordonnées OpenStreetMap Nominatim
  final String? courseId; // Liaison L6 : identifiant du cours rattaché (nullable)
  final String? courseTitle; // Titre du cours rattaché (affiché sur la carte et le détail)
  final OfferStatus status; // draft | published | sold_out | hidden
  final int viewsCount; // Incrémenté à chaque lecture GET /offers/:id
  final int salesCount; // Incrémenté à chaque commande terminée
  final double ratingAvg; // Moyenne des notes (1 à 5 ★)
  final int ratingCount; // Nombre total d'avis reçus
  final int reportsCount; // Compteur de signalements (masquée auto à 3)
  final DateTime createdAt;
  final bool isRecommendedByCourse; // Indique si l'offre est recommandée via Liaison L6

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

/// Modèle d'une Commande ou Réservation (Collection Firestore `orders`, Page 7).
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

/// Avis laissé par l'acheteur après une commande terminée (Collection `reviews`, Page 7).
/// L'identifiant du document [id] est égal à `orderId`, garantissant un seul avis par commande.
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

/// Message d'une conversation liée à une commande (`conversations/{orderId}/messages`, Page 8).
/// Écouté en temps réel via les snapshots Firestore dans l'écran `OrderChatScreen`.
class ChatMessage {
  final String id;
  final String orderId;
  final String senderId;
  final String senderName;
  final String text;
  final String? attachmentUrl; // Pièce jointe envoyée via MediaService (Cloudinary L10)
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
