// Accès à Cloud Firestore pour le Forum (même principe que MarketplaceFirestoreService).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/foundation.dart';
import '../features/forum/models/answer.dart';
import '../features/forum/models/post.dart';
import '../models/rating.dart';
import '../models/reaction.dart';
import 'forum_remote.dart';

/// Couche d'accès Firestore du Forum. Elle ne connaît que les modèles
/// (`toJson` / `fromJson`) ; la logique métier reste dans `ForumProvider`.
///
/// Collections (déjà couvertes par `firestore.rules`) :
/// - `posts/{postId}`
/// - `replies/{replyId}`
/// - `reactions/{targetType_targetId_userId}`
/// - `ratings/{targetType_targetId_userId}`
///
/// Le cache hors-ligne est celui du SDK Firestore (activé par la Marketplace
/// via `enableOfflinePersistence`) : les écritures faites sans réseau sont
/// envoyées automatiquement au retour de la connexion.
class ForumFirestoreService implements ForumRemote {
  ForumFirestoreService([FirebaseFirestore? firestore])
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');
  CollectionReference<Map<String, dynamic>> get _replies =>
      _db.collection('replies');
  CollectionReference<Map<String, dynamic>> get _reactions =>
      _db.collection('reactions');
  CollectionReference<Map<String, dynamic>> get _ratings =>
      _db.collection('ratings');

  // ------------------------------------------------------------------ Lecture

  /// Transforme un instantané en liste de modèles ; un document illisible est
  /// ignoré (il ne doit pas bloquer tout le fil).
  List<T> _parse<T>(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final items = <T>[];
    for (final doc in snapshot.docs) {
      try {
        items.add(fromJson({...doc.data(), 'id': doc.id}));
      } catch (error) {
        debugPrint('Forum : document ${doc.id} ignoré ($error)');
      }
    }
    return items;
  }

  @override
  Stream<List<Post>> watchPosts() =>
      _posts.snapshots().map((s) => _parse(s, Post.fromJson));

  @override
  Stream<List<Answer>> watchReplies() =>
      _replies.snapshots().map((s) => _parse(s, Answer.fromJson));

  @override
  Stream<List<Reaction>> watchReactions() =>
      _reactions.snapshots().map((s) => _parse(s, Reaction.fromJson));

  @override
  Stream<List<Rating>> watchRatings() =>
      _ratings.snapshots().map((s) => _parse(s, Rating.fromJson));

  // ----------------------------------------------------------------- Écriture

  @override
  Future<void> savePost(Post post) =>
      _guard(() => _posts.doc(post.id).set(post.toJson()));

  @override
  Future<void> deletePost(String postId) async {
    // Les suppressions sont lancées dans l'ordre sans attendre l'accusé du
    // serveur (hors-ligne, il n'arrive qu'au retour du réseau) : réponses et
    // réactions d'abord, car les règles lisent la question parente.
    final pending = <Future<void>>[];
    try {
      pending.addAll(await _cascadeDeletes(postId));
    } on FirebaseException catch (error) {
      debugPrint('Forum : nettoyage partiel (${error.code})');
    }
    pending.add(_guard(() => _posts.doc(postId).delete()));
    await Future.wait(pending);
  }

  @override
  Future<void> setAcceptedReply(String postId, {String? replyId}) {
    return _guard(() => _posts.doc(postId).update({
          'acceptedReplyId': replyId,
          'status': replyId == null ? 'open' : 'resolved',
        }));
  }

  @override
  Future<void> saveReply(Answer answer) =>
      _guard(() => _replies.doc(answer.id).set(answer.toJson()));

  @override
  Future<void> deleteReply(String replyId) =>
      _guard(() => _replies.doc(replyId).delete());

  @override
  Future<void> setReplyVerified(
    String replyId, {
    required bool verified,
    DateTime? at,
  }) {
    return _guard(
      () => _replies.doc(replyId).update({
        'isTeacherVerified': verified,
        'verifiedAt': verified ? (at ?? DateTime.now()).toIso8601String() : null,
      }),
      denied: 'Vérification refusée par Firestore : la règle « replies » doit '
          'autoriser les enseignants (voir FORUM_FIREBASE.md) et le compte doit '
          'avoir le rôle enseignant.',
    );
  }

  @override
  Future<void> saveReaction(Reaction reaction, {bool replacing = false}) {
    return _guard(() async {
      final ref = _reactions.doc(reaction.id);
      // Les règles n'autorisent que create / delete sur `reactions` :
      // changer de type = supprimer puis recréer.
      if (replacing) await ref.delete();
      await ref.set(reaction.toJson());
    });
  }

  @override
  Future<void> deleteReaction(Reaction reaction) =>
      _guard(() => _reactions.doc(reaction.id).delete());

  @override
  Future<void> saveRating(Rating rating) =>
      _guard(() => _ratings.doc(rating.id).set(rating.toJson()));

  @override
  Future<void> deleteRating(Rating rating) =>
      _guard(() => _ratings.doc(rating.id).delete());

  @override
  void close() {}

  // ------------------------------------------------------------------ Interne

  /// Lance la suppression, au mieux, des réponses et réactions rattachées à une
  /// question. Les règles n'autorisent chacun qu'à supprimer ses propres
  /// documents : les autres restent orphelins (le client les ignore).
  Future<List<Future<void>>> _cascadeDeletes(String postId) async {
    final deletions = <Future<void>>[];
    final replies = await _replies.where('postId', isEqualTo: postId).get();
    final targetIds = <String>[postId, ...replies.docs.map((d) => d.id)];
    for (final doc in replies.docs) {
      deletions.add(_tryDelete(doc.reference));
    }
    for (final id in targetIds) {
      final reactions = await _reactions.where('targetId', isEqualTo: id).get();
      for (final doc in reactions.docs) {
        deletions.add(_tryDelete(doc.reference));
      }
      final ratings = await _ratings.where('targetId', isEqualTo: id).get();
      for (final doc in ratings.docs) {
        deletions.add(_tryDelete(doc.reference));
      }
    }
    return deletions;
  }

  Future<void> _tryDelete(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      await ref.delete();
    } on FirebaseException {
      // Document d'un autre utilisateur : suppression refusée par les règles.
    }
  }

  /// [denied] remplace le message générique d'un refus de permission.
  Future<void> _guard(Future<void> Function() action, {String? denied}) async {
    try {
      await action();
    } on FirebaseException catch (error) {
      final message = error.code == 'permission-denied' && denied != null
          ? denied
          : _messageFor(error);
      throw ForumRemoteException(message, code: error.code);
    }
  }

  String _messageFor(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Action refusée par les règles de sécurité Firestore.';
      case 'unauthenticated':
        return 'Connectez-vous pour synchroniser le forum.';
      case 'unavailable':
        return 'Serveur injoignable : modification gardée sur l\'appareil.';
      case 'not-found':
        return 'Élément introuvable sur le serveur.';
      default:
        return 'Erreur Firestore (${error.code}).';
    }
  }
}
