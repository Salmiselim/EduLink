// Accès à Cloud Firestore : base NoSQL distante + cache local SQLite géré par le SDK.
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/marketplace_models.dart';

/// Couche d'accès aux données Firestore de la Marketplace.
/// Elle ne connaît que les modèles (toMap / fromMap) : le contrôleur s'occupe de la logique métier.
///
/// Collections utilisées :
/// - `offers/{offerId}`
/// - `availabilities/{slotId}`
/// - `orders/{orderId}`
/// - `reviews/{orderId}`
/// - `favorites/{userId}_{offerId}`
/// - `conversations/{orderId}/messages/{messageId}`
class MarketplaceFirestoreService {
  MarketplaceFirestoreService([FirebaseFirestore? firestore])
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _offers => _db.collection('offers');
  CollectionReference<Map<String, dynamic>> get _slots => _db.collection('availabilities');
  CollectionReference<Map<String, dynamic>> get _orders => _db.collection('orders');
  CollectionReference<Map<String, dynamic>> get _reviews => _db.collection('reviews');
  CollectionReference<Map<String, dynamic>> get _favorites => _db.collection('favorites');

  CollectionReference<Map<String, dynamic>> _messages(String orderId) =>
      _db.collection('conversations').doc(orderId).collection('messages');

  /// Active le cache local persistant (base SQLite sur le téléphone) : lecture hors-ligne
  /// et synchronisation automatique des écritures dès que le réseau revient.
  static void enableOfflinePersistence() {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // ---------------------------------------------------------------- CREATE / UPDATE

  /// `set` crée le document s'il n'existe pas, sinon le remplace (upsert).
  Future<void> saveOffer(Offer o) => _offers.doc(o.id).set(o.toMap());

  Future<void> saveSlot(AvailabilitySlot s) => _slots.doc(s.id).set(s.toMap());

  Future<void> saveOrder(MarketplaceOrder o) => _orders.doc(o.id).set(o.toMap());

  Future<void> saveReview(OfferReview r) => _reviews.doc(r.id).set(r.toMap());

  Future<void> saveMessage(ChatMessage m) =>
      _messages(m.orderId).doc(m.id).set(m.toMap());

  Future<void> setFavorite(String userId, String offerId, bool value) {
    final ref = _favorites.doc('${userId}_$offerId');
    return value
        ? ref.set({'userId': userId, 'offerId': offerId})
        : ref.delete();
  }

  // ---------------------------------------------------------------- DELETE

  /// Supprime l'offre et tous ses créneaux dans un seul batch atomique.
  Future<void> deleteOffer(String offerId) async {
    final batch = _db.batch();
    batch.delete(_offers.doc(offerId));
    final slots = await _slots.where('offerId', isEqualTo: offerId).get();
    for (final d in slots.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  Future<void> deleteSlot(String slotId) => _slots.doc(slotId).delete();

  // ---------------------------------------------------------------- READ (temps réel)

  Stream<List<Offer>> watchOffers() =>
      _offers.snapshots().map((s) => s.docs.map((d) => Offer.fromMap(d.data())).toList());

  Stream<List<AvailabilitySlot>> watchSlots() => _slots
      .snapshots()
      .map((s) => s.docs.map((d) => AvailabilitySlot.fromMap(d.data())).toList());

  Stream<List<MarketplaceOrder>> watchOrders() => _orders
      .snapshots()
      .map((s) => s.docs.map((d) => MarketplaceOrder.fromMap(d.data())).toList());

  Stream<List<OfferReview>> watchReviews() => _reviews
      .snapshots()
      .map((s) => s.docs.map((d) => OfferReview.fromMap(d.data())).toList());

  /// Tous les messages de toutes les conversations (requête `collectionGroup`).
  Stream<List<ChatMessage>> watchMessages() => _db
      .collectionGroup('messages')
      .snapshots()
      .map((s) => s.docs.map((d) => ChatMessage.fromMap(d.data())).toList());

  Stream<Set<String>> watchFavorites(String userId) => _favorites
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()['offerId'] as String).toSet());

  /// Indique si la collection d'offres est vide (pour injecter les données de démonstration).
  Future<bool> isOffersEmpty() async => (await _offers.limit(1).get()).docs.isEmpty;

  /// Insère en une seule écriture groupée le jeu de données de démonstration.
  Future<void> seed({
    required List<Offer> offers,
    required Iterable<AvailabilitySlot> slots,
    required List<MarketplaceOrder> orders,
    required List<OfferReview> reviews,
    required Iterable<ChatMessage> messages,
  }) async {
    final batch = _db.batch();
    for (final o in offers) {
      batch.set(_offers.doc(o.id), o.toMap());
    }
    for (final s in slots) {
      batch.set(_slots.doc(s.id), s.toMap());
    }
    for (final o in orders) {
      batch.set(_orders.doc(o.id), o.toMap());
    }
    for (final r in reviews) {
      batch.set(_reviews.doc(r.id), r.toMap());
    }
    for (final m in messages) {
      batch.set(_messages(m.orderId).doc(m.id), m.toMap());
    }
    await batch.commit();
  }
}
