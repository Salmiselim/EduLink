import '../features/forum/models/answer.dart';
import '../features/forum/models/post.dart';
import '../models/rating.dart';
import '../models/reaction.dart';

/// Erreur d'accès au serveur du Forum, avec un message prêt à afficher.
class ForumRemoteException implements Exception {
  final String message;

  /// Code technique éventuel (ex. `permission-denied`).
  final String? code;

  const ForumRemoteException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Contrat de la base distante du Forum (implémenté par `ForumFirestoreService`
/// en production et par une fausse base en mémoire dans les tests).
///
/// Lecture : trois flux temps réel (questions, réponses, réactions) qui
/// renvoient à chaque changement la liste complète des documents.
/// Écriture : une méthode par action métier ; les droits sont contrôlés par
/// les règles de sécurité Firestore (`firestore.rules`).
abstract class ForumRemote {
  Stream<List<Post>> watchPosts();
  Stream<List<Answer>> watchReplies();
  Stream<List<Reaction>> watchReactions();
  Stream<List<Rating>> watchRatings();

  /// Crée ou remplace une question (réservé à son auteur).
  Future<void> savePost(Post post);

  /// Supprime la question puis, au mieux, ses réponses et réactions.
  Future<void> deletePost(String postId);

  /// Accepte une réponse ([replyId]) ou retire l'acceptation (null).
  Future<void> setAcceptedReply(String postId, {String? replyId});

  /// Crée ou remplace une réponse (réservé à son auteur).
  Future<void> saveReply(Answer answer);

  Future<void> deleteReply(String replyId);

  /// Marque ou démarque une réponse comme vérifiée par un enseignant.
  Future<void> setReplyVerified(
    String replyId, {
    required bool verified,
    DateTime? at,
  });

  /// Enregistre la réaction ; [replacing] vrai quand elle remplace une
  /// réaction existante du même utilisateur (changement de type).
  Future<void> saveReaction(Reaction reaction, {bool replacing = false});

  Future<void> deleteReaction(Reaction reaction);

  /// Crée ou remplace la note (1 à 5 étoiles) de l'utilisateur sur une cible.
  Future<void> saveRating(Rating rating);

  Future<void> deleteRating(Rating rating);

  /// Libère les ressources éventuelles.
  void close();
}
