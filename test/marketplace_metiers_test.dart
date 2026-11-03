import 'package:flutter_test/flutter_test.dart';
import 'package:edulink/features/marketplace/data/marketplace_mock_data.dart';
import 'package:edulink/features/marketplace/models/marketplace_models.dart';

void main() {
  late MarketplaceController controller;

  setUp(() {
    controller = MarketplaceController.instance;
  });

  group('Métier 1 : Catalogue, Création, Disponibilités & Modération', () {
    test('Création d\'une offre avec créneaux et persistance dans le catalogue', () {
      final initialCount = controller.allOffers.length;
      final testOffer = Offer(
        id: 'test_offer_algo_99',
        sellerId: controller.currentUserId,
        sellerName: controller.currentUserName,
        sellerAvatar: 'https://i.pravatar.cc/150?u=me',
        sellerSubtitle: 'Étudiant en L3',
        sellerRole: SellerRole.student,
        type: OfferType.privateLesson,
        title: 'Cours Test Algorithmique Avancée',
        subject: 'Algorithmique',
        level: 'L3',
        description: 'Préparation intensive aux examens.',
        price: 30.0,
        createdAt: DateTime.now(),
      );

      final slot = AvailabilitySlot(
        id: 'slot_test_1',
        offerId: testOffer.id,
        sellerId: testOffer.sellerId,
        date: 'Mer 28 Oct 2026',
        startTime: '10:00',
        endTime: '11:00',
      );

      controller.addOffer(testOffer, slots: [slot]);

      expect(controller.allOffers.length, initialCount + 1);
      expect(controller.getSlotsForOffer(testOffer.id).length, 1);
      expect(controller.getSlotsForOffer(testOffer.id).first.isBooked, isFalse);

      // Favoris
      expect(controller.isFavorite(testOffer.id), isFalse);
      controller.toggleFavorite(testOffer.id);
      expect(controller.isFavorite(testOffer.id), isTrue);
      controller.toggleFavorite(testOffer.id);
      expect(controller.isFavorite(testOffer.id), isFalse);
    });

    test('Modération automatique : Masquage après 3 signalements', () {
      final offer = controller.allOffers.first;
      final offerId = offer.id;

      // S'assurer que le statut initial est published
      controller.updateOfferStatus(offerId, OfferStatus.published);

      controller.reportOffer(offerId, 'Contenu inapproprié');
      controller.reportOffer(offerId, 'Spam');
      final autoHidden = controller.reportOffer(offerId, 'Arnaque');

      expect(autoHidden, isTrue);
      final updated = controller.allOffers.firstWhere((o) => o.id == offerId);
      expect(updated.status, equals(OfferStatus.hidden));
    });
  });

  group('Métier 2 : Réservation de créneau, Verrouillage & Cycle de Vie Commande', () {
    test('La réservation verrouille le créneau et l\'acceptation génère la salle Jitsi Meet', () {
      final lessonOffer = controller.allOffers.firstWhere(
        (o) => o.type == OfferType.privateLesson && o.status == OfferStatus.published,
      );

      controller.addAvailabilitySlot(
        lessonOffer.id,
        'Jeu 29 Oct 2026',
        '14:00',
        '15:00',
      );

      final slot = controller.getSlotsForOffer(lessonOffer.id).last;
      expect(slot.isBooked, isFalse);

      // Création de la commande par l'acheteur
      final order = controller.createOrder(
        offer: lessonOffer,
        selectedSlot: slot,
        note: 'Besoin d\'aide sur les graphes',
      );

      expect(order.status, equals(OrderStatus.requested));
      // Vérification du verrouillage anti-double réservation
      final updatedSlot = controller
          .getSlotsForOffer(lessonOffer.id)
          .firstWhere((s) => s.id == slot.id);
      expect(updatedSlot.isBooked, isTrue);
      expect(updatedSlot.orderId, equals(order.id));

      // Le vendeur accepte la commande -> génération automatique du lien Jitsi Meet
      controller.updateOrderStatus(order.id, OrderStatus.accepted);
      final acceptedOrder = controller.allOrders.firstWhere((o) => o.id == order.id);

      expect(acceptedOrder.status, equals(OrderStatus.accepted));
      expect(acceptedOrder.meetingLink, contains('meet.jit.si/edulink-${order.id}'));

      // Marquer comme terminée
      controller.updateOrderStatus(order.id, OrderStatus.completed);
      final completedOrder = controller.allOrders.firstWhere((o) => o.id == order.id);
      expect(completedOrder.status, equals(OrderStatus.completed));
    });

    test('Le refus d\'une commande libère immédiatement le créneau réservé', () {
      final lessonOffer = controller.allOffers.firstWhere(
        (o) => o.type == OfferType.privateLesson,
      );

      controller.addAvailabilitySlot(
        lessonOffer.id,
        'Ven 30 Oct 2026',
        '16:00',
        '17:00',
      );

      final slot = controller.getSlotsForOffer(lessonOffer.id).last;
      final order = controller.createOrder(
        offer: lessonOffer,
        selectedSlot: slot,
        note: 'Demande test',
      );

      expect(
        controller.getSlotsForOffer(lessonOffer.id).firstWhere((s) => s.id == slot.id).isBooked,
        isTrue,
      );

      // Vendeur refuse la commande
      controller.updateOrderStatus(order.id, OrderStatus.rejected);

      // Le créneau doit être redevenu libre
      final freedSlot = controller
          .getSlotsForOffer(lessonOffer.id)
          .firstWhere((s) => s.id == slot.id);
      expect(freedSlot.isBooked, isFalse);
      expect(freedSlot.orderId, isNull);
    });
  });

  group('Métier 3 : Chat en direct & Évaluation après service (Avis vérifié)', () {
    test('Échange de messages dans la commande et dépôt d\'un avis noté 5 étoiles', () {
      final order = controller.allOrders.first;

      // 1. Envoi d'un message
      final initialMsgCount = controller.getMessagesForOrder(order.id).length;
      controller.sendMessage(order.id, 'Bonjour, je serai à l\'heure pour le cours !');
      expect(controller.getMessagesForOrder(order.id).length, initialMsgCount + 1);

      // 2. Clôture de la commande
      controller.updateOrderStatus(order.id, OrderStatus.completed);
      final completedOrder = controller.allOrders.firstWhere((o) => o.id == order.id);

      // 3. Dépôt de l'avis vérifié (1 à 5 étoiles)
      final offerBefore = controller.allOffers.firstWhere((o) => o.id == completedOrder.offerId);
      final initialRatingCount = offerBefore.ratingCount;

      controller.submitReview(
        order: completedOrder,
        rating: 5,
        comment: 'Excellent professeur, explications très claires !',
      );

      // Vérification que la commande est marquée hasReview = true
      final orderAfter = controller.allOrders.firstWhere((o) => o.id == order.id);
      expect(orderAfter.hasReview, isTrue);

      // Vérification de la note moyenne recalculée sur l'offre
      final offerAfter = controller.allOffers.firstWhere((o) => o.id == completedOrder.offerId);
      expect(offerAfter.ratingCount, equals(initialRatingCount + 1));
      expect(controller.getReviewsForOffer(offerAfter.id).first.rating, equals(5));
    });
  });
}
