import 'dart:async';

import 'package:edulink/models/answer.dart';
import 'package:edulink/models/post.dart';
import 'package:edulink/models/rating.dart';
import 'package:edulink/models/reaction.dart';
import 'package:edulink/models/user.dart';
import 'package:edulink/providers/forum_provider.dart';
import 'package:edulink/services/forum_remote.dart';
import 'package:edulink/services/forum_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fausse base distante en mémoire (remplace Firestore dans les tests) :
/// émet la liste complète à chaque changement, comme les flux Firestore.
class FakeForumRemote implements ForumRemote {
  final Map<String, Post> posts = {};
  final Map<String, Answer> replies = {};
  final Map<String, Reaction> reactions = {};
  final Map<String, Rating> ratings = {};
  final List<String> calls = [];

  /// Si défini, la prochaine écriture échoue avec cette erreur.
  ForumRemoteException? failNext;

  final _postsCtrl = StreamController<List<Post>>.broadcast();
  final _repliesCtrl = StreamController<List<Answer>>.broadcast();
  final _reactionsCtrl = StreamController<List<Reaction>>.broadcast();
  final _ratingsCtrl = StreamController<List<Rating>>.broadcast();

  // Chaque émission renvoie des copies : le serveur et l'appli ne partagent
  // jamais les mêmes objets (comme avec un vrai réseau).
  List<Post> _postList() =>
      posts.values.map((p) => Post.fromJson(p.toJson())).toList();
  List<Answer> _replyList() =>
      replies.values.map((a) => Answer.fromJson(a.toJson())).toList();

  @override
  Stream<List<Post>> watchPosts() async* {
    yield _postList();
    yield* _postsCtrl.stream;
  }

  @override
  Stream<List<Answer>> watchReplies() async* {
    yield _replyList();
    yield* _repliesCtrl.stream;
  }

  @override
  Stream<List<Reaction>> watchReactions() async* {
    yield reactions.values.toList();
    yield* _reactionsCtrl.stream;
  }

  @override
  Stream<List<Rating>> watchRatings() async* {
    yield ratings.values.toList();
    yield* _ratingsCtrl.stream;
  }

  void _emit() {
    _postsCtrl.add(_postList());
    _repliesCtrl.add(_replyList());
    _reactionsCtrl.add(reactions.values.toList());
    _ratingsCtrl.add(ratings.values.toList());
  }

  void _check() {
    final error = failNext;
    if (error != null) {
      failNext = null;
      throw error;
    }
  }

  /// Simule une écriture faite par un autre utilisateur.
  void seed({Post? post, Answer? reply, Reaction? reaction, Rating? rating}) {
    if (post != null) posts[post.id] = Post.fromJson(post.toJson());
    if (reply != null) replies[reply.id] = Answer.fromJson(reply.toJson());
    if (reaction != null) reactions[reaction.id] = reaction;
    if (rating != null) ratings[rating.id] = rating;
    _emit();
  }

  @override
  Future<void> savePost(Post post) async {
    calls.add('savePost ${post.id}');
    _check();
    posts[post.id] = Post.fromJson(post.toJson());
    _emit();
  }

  @override
  Future<void> deletePost(String postId) async {
    calls.add('deletePost $postId');
    _check();
    posts.remove(postId);
    replies.removeWhere((_, a) => a.postId == postId);
    _emit();
  }

  @override
  Future<void> setAcceptedReply(String postId, {String? replyId}) async {
    calls.add('setAcceptedReply $postId ${replyId ?? 'null'}');
    _check();
    final post = posts[postId];
    if (post == null) return;
    post.acceptedReplyId = replyId;
    post.status = replyId == null ? PostStatus.open : PostStatus.resolved;
    _emit();
  }

  @override
  Future<void> saveReply(Answer answer) async {
    calls.add('saveReply ${answer.id}');
    _check();
    replies[answer.id] = Answer.fromJson(answer.toJson());
    _emit();
  }

  @override
  Future<void> deleteReply(String replyId) async {
    calls.add('deleteReply $replyId');
    _check();
    replies.remove(replyId);
    _emit();
  }

  @override
  Future<void> setReplyVerified(
    String replyId, {
    required bool verified,
    DateTime? at,
  }) async {
    calls.add('setReplyVerified $replyId $verified');
    _check();
    final reply = replies[replyId];
    if (reply == null) return;
    reply.isTeacherVerified = verified;
    reply.verifiedAt = verified ? at : null;
    _emit();
  }

  @override
  Future<void> saveReaction(Reaction reaction, {bool replacing = false}) async {
    calls.add('saveReaction ${reaction.id} replacing=$replacing');
    _check();
    reactions[reaction.id] = reaction;
    _emit();
  }

  @override
  Future<void> deleteReaction(Reaction reaction) async {
    calls.add('deleteReaction ${reaction.id}');
    _check();
    reactions.remove(reaction.id);
    _emit();
  }

  @override
  Future<void> saveRating(Rating rating) async {
    calls.add('saveRating ${rating.id} ${rating.stars}');
    _check();
    ratings[rating.id] = rating;
    _emit();
  }

  @override
  Future<void> deleteRating(Rating rating) async {
    calls.add('deleteRating ${rating.id}');
    _check();
    ratings.remove(rating.id);
    _emit();
  }

  @override
  void close() {}
}

/// Stockage qui échoue toujours (appareil sans stockage disponible).
class _BrokenStore implements ForumStore {
  @override
  Future<ForumSnapshot?> load() async => throw Exception('indisponible');

  @override
  Future<void> save(ForumSnapshot snapshot) async =>
      throw Exception('indisponible');

  @override
  Future<void> clear() async {}
}

ForumProvider makeProvider([ForumStore? store]) =>
    ForumProvider(store: store ?? MemoryForumStore(), linkFirebase: false);

/// Crée une question en tant qu'étudiant (Selim) et renvoie son identifiant.
String addQuestion(ForumProvider provider, {String title = 'Ma question test'}) {
  return provider.createPost(
    title: title,
    body: 'Description de la question de test',
    courseName: 'Architecture Logicielle',
  );
}

void main() {
  group('Filtres, recherche et pagination', () {
    test('affiche toutes les questions au départ, la plus récente en premier', () {
      final provider = makeProvider();
      expect(provider.filteredPosts.length, 4);
      expect(provider.filteredPosts.first.id, 'post_4');
      expect(provider.hasActiveFilters, isFalse);
    });

    test('filtre par cours', () {
      final provider = makeProvider();
      provider.setSelectedCourse('Algorithmique & Complexité');
      expect(provider.filteredPosts.map((p) => p.id).toSet(),
          {'post_2', 'post_4'});
    });

    test('recherche insensible à la casse, avec espaces ignorés', () {
      final provider = makeProvider();
      provider.setSearchQuery('  MONGOOSE ');
      expect(provider.filteredPosts.map((p) => p.id), ['post_3']);
    });

    test('filtre par tag', () {
      final provider = makeProvider();
      provider.setTagFilter('python');
      expect(provider.filteredPosts.map((p) => p.id), ['post_4']);
    });

    test('filtre par état : sans réponse et résolues', () {
      final provider = makeProvider();
      provider.setStatusFilter(ForumStatusFilter.unanswered);
      expect(provider.filteredPosts.map((p) => p.id), ['post_3']);

      provider.setStatusFilter(ForumStatusFilter.resolved);
      expect(provider.filteredPosts, isEmpty);
    });

    test('resetFilters remet tout à zéro', () {
      final provider = makeProvider();
      provider.setSearchQuery('flutter');
      provider.setSelectedCourse('Architecture Logicielle');
      provider.setTagFilter('flutter');
      provider.setStatusFilter(ForumStatusFilter.resolved);
      expect(provider.hasActiveFilters, isTrue);

      provider.resetFilters();
      expect(provider.hasActiveFilters, isFalse);
      expect(provider.filteredPosts.length, 4);
    });

    test('la pagination affiche 10 questions puis charge la suite', () {
      final provider = makeProvider();
      for (var i = 0; i < 12; i++) {
        addQuestion(provider, title: 'Question numéro $i');
      }
      expect(provider.filteredPosts.length, 16);
      expect(provider.visiblePosts.length, ForumProvider.pageSize);
      expect(provider.hasMore, isTrue);

      provider.loadMore();
      expect(provider.visiblePosts.length, 16);
      expect(provider.hasMore, isFalse);
    });
  });

  group('CRUD des questions', () {
    test('createPost ajoute en tête, nettoie les tags et ignore un code vide', () {
      final provider = makeProvider();
      final id = provider.createPost(
        title: '  Nouvelle question  ',
        body: 'Corps de la question',
        courseName: 'Architecture Logicielle',
        tags: ['Flutter', 'flutter', ' Dart ', ''],
        codeSnippet: '   ',
        codeLanguage: 'python',
      );

      final post = provider.getPostById(id)!;
      expect(provider.filteredPosts.first.id, id);
      expect(post.title, 'Nouvelle question');
      expect(post.tags, ['flutter', 'dart']);
      expect(post.hasCode, isFalse);
      expect(post.codeLanguage, isNull);
      expect(post.authorId, 'user_selim');
    });

    test('createPost conserve un extrait de code et son langage', () {
      final provider = makeProvider();
      final id = provider.createPost(
        title: 'Question avec du code',
        body: 'Corps de la question',
        courseName: 'Architecture Logicielle',
        codeSnippet: 'print("salut")\n\n',
        codeLanguage: 'python',
      );
      final post = provider.getPostById(id)!;
      expect(post.codeSnippet, 'print("salut")');
      expect(post.codeLanguage, 'python');
    });

    test('getPostById trouve une question même si un filtre la masque', () {
      final provider = makeProvider();
      final id = addQuestion(provider);
      provider.setSelectedCourse('Algorithmique & Complexité');

      expect(provider.filteredPosts.any((p) => p.id == id), isFalse);
      expect(provider.getPostById(id), isNotNull);
    });

    test("l'auteur modifie sa question", () {
      final provider = makeProvider();
      final id = addQuestion(provider);

      final ok = provider.updatePost(
        id,
        title: 'Titre modifié',
        body: 'Nouveau corps de question',
        courseName: 'Algorithmique & Complexité',
        tags: ['algo'],
      );

      final post = provider.getPostById(id)!;
      expect(ok, isTrue);
      expect(post.title, 'Titre modifié');
      expect(post.courseName, 'Algorithmique & Complexité');
      expect(post.tags, ['algo']);
      expect(post.isEdited, isTrue);
    });

    test('un autre utilisateur ne peut ni modifier ni supprimer', () {
      final provider = makeProvider();
      // post_1 appartient à Yassine, l'utilisateur courant est Selim.
      expect(provider.canModifyPost(provider.getPostById('post_1')!), isFalse);
      expect(
        provider.updatePost('post_1',
            title: 'Piraté',
            body: 'Corps piraté',
            courseName: 'Architecture Logicielle'),
        isFalse,
      );
      expect(provider.deletePost('post_1'), isFalse);
      expect(provider.getPostById('post_1')!.title, isNot('Piraté'));
    });

    test('deletePost supprime aussi les réponses et les réactions', () {
      final provider = makeProvider();
      final id = addQuestion(provider);
      final answerId = provider.addAnswer(postId: id, body: 'Une réponse')!;
      provider.toggleReaction(ReactionTarget.post, id, ReactionType.like);
      provider.toggleReaction(
          ReactionTarget.reply, answerId, ReactionType.helpful);

      expect(provider.deletePost(id), isTrue);
      expect(provider.getPostById(id), isNull);
      expect(provider.getAnswerById(answerId), isNull);
      expect(provider.reactionCount(ReactionTarget.post, id), 0);
      expect(provider.reactionCount(ReactionTarget.reply, answerId), 0);
    });
  });

  group('CRUD des réponses', () {
    test(
        'addAnswer incrémente le compteur, ignore le vide et les questions inconnues',
        () {
      final provider = makeProvider();
      final before = provider.getPostById('post_3')!.answersCount;

      expect(provider.addAnswer(postId: 'post_3', body: '   '), isNull);
      expect(provider.addAnswer(postId: 'inconnu', body: 'Bonjour'), isNull);
      expect(provider.getPostById('post_3')!.answersCount, before);

      final id = provider.addAnswer(
        postId: 'post_3',
        body: 'find() renvoie un tableau.',
        codeSnippet: 'db.users.find({})',
        codeLanguage: 'javascript',
      );
      expect(id, isNotNull);
      expect(provider.getPostById('post_3')!.answersCount, before + 1);
      expect(provider.getAnswerById(id!)!.hasCode, isTrue);
    });

    test("seul l'auteur modifie sa réponse", () {
      final provider = makeProvider();
      // ans_3 est de Selim (utilisateur courant), ans_1 de Sarah.
      expect(provider.updateAnswer('ans_3', body: 'Réponse corrigée'), isTrue);
      expect(provider.getAnswerById('ans_3')!.body, 'Réponse corrigée');
      expect(provider.getAnswerById('ans_3')!.isEdited, isTrue);
      expect(provider.updateAnswer('ans_1', body: 'Piratage'), isFalse);
      expect(provider.updateAnswer('ans_3', body: '  '), isFalse);
    });

    test('deleteAnswer décrémente le compteur et supprime les réactions', () {
      final provider = makeProvider();
      final before = provider.getPostById('post_2')!.answersCount;
      expect(provider.reactionCount(ReactionTarget.reply, 'ans_3'), 1);

      expect(provider.deleteAnswer('ans_3'), isTrue);
      expect(provider.getPostById('post_2')!.answersCount, before - 1);
      expect(provider.reactionCount(ReactionTarget.reply, 'ans_3'), 0);
      expect(provider.deleteAnswer('ans_1'), isFalse);
    });
  });

  group('Réponse acceptée et statut', () {
    /// Selim pose une question, l'enseignante répond, puis on revient à Selim.
    ({String postId, String answerId}) questionWithTeacherAnswer(
        ForumProvider provider) {
      final postId = addQuestion(provider);
      provider.setRole(ForumRole.teacher);
      final answerId =
          provider.addAnswer(postId: postId, body: 'Voici la réponse')!;
      provider.setRole(ForumRole.student);
      return (postId: postId, answerId: answerId);
    }

    test("l'auteur accepte une réponse : la question devient résolue", () {
      final provider = makeProvider();
      final q = questionWithTeacherAnswer(provider);

      expect(provider.toggleAcceptAnswer(q.postId, q.answerId), isTrue);
      final post = provider.getPostById(q.postId)!;
      expect(post.isResolved, isTrue);
      expect(post.acceptedReplyId, q.answerId);
      expect(provider.getAnswersForPost(q.postId).first.id, q.answerId);

      provider.setStatusFilter(ForumStatusFilter.resolved);
      expect(provider.filteredPosts.map((p) => p.id), [q.postId]);
    });

    test("retirer l'acceptation rouvre la question", () {
      final provider = makeProvider();
      final q = questionWithTeacherAnswer(provider);
      provider.toggleAcceptAnswer(q.postId, q.answerId);
      provider.toggleAcceptAnswer(q.postId, q.answerId);

      final post = provider.getPostById(q.postId)!;
      expect(post.isResolved, isFalse);
      expect(post.acceptedReplyId, isNull);
    });

    test('un autre utilisateur ne peut pas accepter une réponse', () {
      final provider = makeProvider();
      // post_1 est de Yassine : Selim ne peut pas accepter ans_2.
      expect(provider.toggleAcceptAnswer('post_1', 'ans_2'), isFalse);
      expect(provider.getPostById('post_1')!.isResolved, isFalse);
    });

    test('supprimer la réponse acceptée rouvre la question', () {
      final provider = makeProvider();
      final q = questionWithTeacherAnswer(provider);
      provider.toggleAcceptAnswer(q.postId, q.answerId);
      expect(provider.getPostById(q.postId)!.isResolved, isTrue);

      // L'enseignante (auteur de la réponse) la supprime.
      provider.setRole(ForumRole.teacher);
      expect(provider.deleteAnswer(q.answerId), isTrue);

      final post = provider.getPostById(q.postId)!;
      expect(post.isResolved, isFalse);
      expect(post.acceptedReplyId, isNull);
    });
  });

  group('Rôle enseignant', () {
    test('un étudiant ne peut pas vérifier une réponse', () {
      final provider = makeProvider();
      provider.toggleVerifyAnswer('ans_2');
      expect(provider.getAnswerById('ans_2')!.isTeacherVerified, isFalse);
    });

    test('un enseignant vérifie une réponse, qui passe en tête', () {
      final provider = makeProvider();
      provider.setRole(ForumRole.teacher);
      provider.toggleVerifyAnswer('ans_2');

      final answers = provider.getAnswersForPost('post_1');
      expect(answers.first.id, 'ans_2');
      expect(answers.first.isTeacherVerified, isTrue);
      expect(answers.first.verifiedAt, isNotNull);
    });

    test('pendingPosts ne contient que les questions sans réponse enseignant',
        () {
      final provider = makeProvider();
      expect(provider.pendingPosts.map((p) => p.id), ['post_3']);

      provider.setRole(ForumRole.teacher);
      provider.addAnswer(postId: 'post_3', body: 'find() renvoie un tableau.');
      expect(provider.pendingPosts, isEmpty);
    });

    test('les contenus créés portent le rôle courant', () {
      final provider = makeProvider();
      provider.setRole(ForumRole.teacher);
      final id = addQuestion(provider, title: 'Annonce importante');
      expect(provider.getPostById(id)!.isTeacher, isTrue);
      expect(provider.getPostById(id)!.authorId, 'user_sarah');
    });
  });

  group('Réactions', () {
    test("les données d'exemple comptent les réactions par type", () {
      final provider = makeProvider();
      expect(provider.reactionCount(ReactionTarget.reply, 'ans_1'), 5);
      expect(
          provider.reactionCount(ReactionTarget.reply, 'ans_1',
              type: ReactionType.helpful),
          2);
      expect(provider.myReaction(ReactionTarget.reply, 'ans_1'),
          ReactionType.helpful);
    });

    test('toucher la même réaction la retire', () {
      final provider = makeProvider();
      provider.toggleReaction(
          ReactionTarget.reply, 'ans_1', ReactionType.helpful);
      expect(provider.reactionCount(ReactionTarget.reply, 'ans_1'), 4);
      expect(provider.myReaction(ReactionTarget.reply, 'ans_1'), isNull);
    });

    test(
        'choisir un autre type remplace la réaction (une seule par utilisateur)',
        () {
      final provider = makeProvider();
      provider.toggleReaction(ReactionTarget.reply, 'ans_1', ReactionType.like);
      expect(provider.reactionCount(ReactionTarget.reply, 'ans_1'), 5);
      expect(provider.myReaction(ReactionTarget.reply, 'ans_1'),
          ReactionType.like);
      expect(
          provider.reactionCount(ReactionTarget.reply, 'ans_1',
              type: ReactionType.helpful),
          1);
    });

    test('chaque rôle a sa propre réaction', () {
      final provider = makeProvider();
      provider.toggleReaction(ReactionTarget.post, 'post_3', ReactionType.like);
      provider.setRole(ForumRole.teacher);
      provider.toggleReaction(
          ReactionTarget.post, 'post_3', ReactionType.insightful);

      expect(provider.reactionCount(ReactionTarget.post, 'post_3'), 2);
      expect(provider.myReaction(ReactionTarget.post, 'post_3'),
          ReactionType.insightful);
    });
  });

  group('Stockage local', () {
    test('les données sont retrouvées au redémarrage', () async {
      final store = MemoryForumStore();
      final first = makeProvider(store);
      await first.init();
      final id = addQuestion(first, title: 'Question persistante');
      first.toggleReaction(ReactionTarget.post, id, ReactionType.helpful);
      first.setRole(ForumRole.teacher);
      await first.persistenceIdle;

      final second = makeProvider(store);
      await second.init();

      expect(second.isReady, isTrue);
      expect(second.getPostById(id)!.title, 'Question persistante');
      expect(second.reactionCount(ReactionTarget.post, id), 1);
      expect(second.isTeacher, isTrue);
    });

    test("le premier lancement enregistre les données d'exemple", () async {
      final store = MemoryForumStore();
      await makeProvider(store).init();
      final snapshot = await store.load();
      expect(snapshot, isNotNull);
      expect(snapshot!.posts.length, 4);
    });

    test('une suppression est bien persistée', () async {
      final store = MemoryForumStore();
      final first = makeProvider(store);
      await first.init();
      final id = addQuestion(first);
      first.deletePost(id);
      await first.persistenceIdle;

      final second = makeProvider(store);
      await second.init();
      expect(second.getPostById(id), isNull);
      expect(second.filteredPosts.length, 4);
    });

    test("un stockage indisponible n'empêche pas l'utilisation", () async {
      final provider = makeProvider(_BrokenStore());
      await provider.init();
      addQuestion(provider);
      await provider.persistenceIdle;

      expect(provider.isReady, isTrue);
      expect(provider.filteredPosts.length, 5);
    });
  });

  group('Notes, réactions emoji et classement', () {
    test('la moyenne et le nombre de notes viennent des données', () {
      final provider = makeProvider();
      final stats = provider.ratingStats(ReactionTarget.reply, 'ans_1');
      expect(stats.count, 4);
      expect(stats.average, closeTo(4.75, 0.001));
    });

    test('on note, on change de note, puis on retire la note', () {
      final provider = makeProvider();
      expect(provider.myRating(ReactionTarget.reply, 'ans_2'), isNull);

      expect(provider.rate(ReactionTarget.reply, 'ans_2', 5), isTrue);
      expect(provider.myRating(ReactionTarget.reply, 'ans_2'), 5);
      expect(provider.ratingStats(ReactionTarget.reply, 'ans_2').count, 3);

      provider.rate(ReactionTarget.reply, 'ans_2', 3);
      expect(provider.myRating(ReactionTarget.reply, 'ans_2'), 3);
      expect(provider.ratingStats(ReactionTarget.reply, 'ans_2').count, 3);

      provider.rate(ReactionTarget.reply, 'ans_2', 3); // même note = retrait
      expect(provider.myRating(ReactionTarget.reply, 'ans_2'), isNull);
      expect(provider.ratingStats(ReactionTarget.reply, 'ans_2').count, 2);
    });

    test('refuse une note hors 1-5 et la note de son propre contenu', () {
      final provider = makeProvider();
      expect(provider.rate(ReactionTarget.reply, 'ans_2', 0), isFalse);
      expect(provider.rate(ReactionTarget.reply, 'ans_2', 6), isFalse);

      // ans_3 a été écrite par Selim, l'utilisateur courant.
      expect(provider.canRate(ReactionTarget.reply, 'ans_3'), isFalse);
      expect(provider.rate(ReactionTarget.reply, 'ans_3', 5), isFalse);

      final id = addQuestion(provider);
      expect(provider.rate(ReactionTarget.post, id, 5), isFalse);
      expect(provider.rate(ReactionTarget.post, 'inconnu', 5), isFalse);
    });

    test('« Mieux notées » classe le fil avec le score bayésien', () {
      final provider = makeProvider();
      provider.setSortOrder(ForumSortOrder.topRated);
      var ids = provider.filteredPosts.map((p) => p.id).toList();
      expect(ids.first, 'post_1'); // 4 et 5 étoiles
      expect(ids.last, 'post_3'); // une seule note de 3 étoiles

      // Une note de 5 étoiles fait remonter post_3 au-dessus des questions sans note.
      provider.rate(ReactionTarget.post, 'post_3', 5);
      ids = provider.filteredPosts.map((p) => p.id).toList();
      expect(ids.first, 'post_1');
      expect(ids[1], 'post_3');
    });

    test('« Populaires » classe selon réactions, notes et réponses', () {
      final provider = makeProvider();
      provider.setSortOrder(ForumSortOrder.popular);
      int engagement(Post p) =>
          provider.reactionCount(ReactionTarget.post, p.id) +
          2 * provider.ratingStats(ReactionTarget.post, p.id).count +
          p.answersCount;
      final list = provider.filteredPosts;
      for (var i = 0; i < list.length - 1; i++) {
        expect(engagement(list[i]) >= engagement(list[i + 1]), isTrue);
      }
    });

    test("revenir à « Récentes » rétablit l'ordre par date", () {
      final provider = makeProvider();
      provider.setSortOrder(ForumSortOrder.topRated);
      provider.setSortOrder(ForumSortOrder.recent);
      expect(provider.filteredPosts.first.id, 'post_4');
      expect(provider.hasActiveFilters, isFalse);
    });

    test("les réponses les mieux notées remontent, l'acceptée reste en tête",
        () {
      final provider = makeProvider();
      final id = addQuestion(provider);
      provider.setRole(ForumRole.teacher);
      final first = provider.addAnswer(postId: id, body: 'Première réponse')!;
      final second = provider.addAnswer(postId: id, body: 'Deuxième réponse')!;
      provider.setRole(ForumRole.student);

      provider.rate(ReactionTarget.reply, second, 5);
      provider.rate(ReactionTarget.reply, first, 1);
      expect(provider.getAnswersForPost(id).map((a) => a.id), [second, first]);

      provider.toggleAcceptAnswer(id, first);
      expect(provider.getAnswersForPost(id).first.id, first);
    });

    test('supprimer une réponse ou une question supprime ses notes', () {
      final provider = makeProvider();
      final id = addQuestion(provider);
      provider.setRole(ForumRole.teacher);
      final answerId = provider.addAnswer(postId: id, body: 'Une réponse')!;
      provider.rate(ReactionTarget.post, id, 4);
      provider.setRole(ForumRole.student);
      provider.rate(ReactionTarget.reply, answerId, 5);

      provider.setRole(ForumRole.teacher);
      provider.deleteAnswer(answerId);
      expect(provider.ratingStats(ReactionTarget.reply, answerId).count, 0);

      provider.setRole(ForumRole.student);
      provider.deletePost(id);
      expect(provider.ratingStats(ReactionTarget.post, id).count, 0);
    });

    test('les nouvelles réactions emoji se posent comme les anciennes', () {
      final provider = makeProvider();
      provider.toggleReaction(
          ReactionTarget.post, 'post_3', ReactionType.applause);
      expect(provider.myReaction(ReactionTarget.post, 'post_3'),
          ReactionType.applause);
      provider.toggleReaction(
          ReactionTarget.post, 'post_3', ReactionType.relevant);
      expect(provider.myReaction(ReactionTarget.post, 'post_3'),
          ReactionType.relevant);
      expect(provider.reactionCount(ReactionTarget.post, 'post_3'), 1);
    });

    test('les notes sont enregistrées en local', () async {
      final store = MemoryForumStore();
      final first = makeProvider(store);
      await first.init();
      first.rate(ReactionTarget.reply, 'ans_2', 2);
      await first.persistenceIdle;

      final second = makeProvider(store);
      await second.init();
      expect(second.myRating(ReactionTarget.reply, 'ans_2'), 2);
    });
  });

  group('Mode connecté (Cloud Firestore simulé)', () {
    const student =
        ForumUser(id: 'uid_amel', name: 'Amel Ben Salah', role: ForumRole.student);
    const teacher = ForumUser(
        id: 'uid_prof', name: 'Dr. Karim', role: ForumRole.teacher);

    Future<({ForumProvider provider, FakeForumRemote remote})> connect({
      ForumUser user = student,
      ForumStore? store,
    }) async {
      final provider = makeProvider(store);
      final remote = FakeForumRemote();
      provider.connectRemote(remote, user: user);
      await pumpEventQueue();
      return (provider: provider, remote: remote);
    }

    Post remotePost({String id = 'remote_1', String authorId = 'uid_autre'}) {
      return Post(
        id: id,
        authorId: authorId,
        authorName: 'Camarade',
        courseName: 'Architecture Logicielle',
        title: 'Question venue du serveur',
        body: 'Corps de la question distante',
        createdAt: DateTime.now(),
      );
    }

    Answer remoteReply(String id, {String postId = 'remote_1'}) {
      return Answer(
        id: id,
        postId: postId,
        authorId: 'uid_prof',
        authorName: 'Dr. Karim',
        authorRole: 'teacher',
        body: 'Réponse du serveur',
        createdAt: DateTime.now(),
      );
    }

    test("la connexion remplace les données d'exemple par celles du serveur",
        () async {
      final provider = makeProvider();
      expect(provider.filteredPosts.length, 4);
      expect(provider.isOnline, isFalse);

      final remote = FakeForumRemote()..seed(post: remotePost());
      provider.connectRemote(remote, user: student);
      await pumpEventQueue();

      expect(provider.isOnline, isTrue);
      expect(provider.filteredPosts.map((p) => p.id), ['remote_1']);
      expect(provider.currentUser.id, 'uid_amel');
    });

    test("les contenus créés portent l'identité du compte connecté", () async {
      final c = await connect();
      final id = addQuestion(c.provider);
      await pumpEventQueue();

      expect(c.remote.calls, contains('savePost $id'));
      expect(c.remote.posts[id]!.authorId, 'uid_amel');
      expect(c.remote.posts[id]!.authorName, 'Amel Ben Salah');
      expect(c.provider.getPostById(id), isNotNull);
      expect(c.provider.canModifyPost(c.provider.getPostById(id)!), isTrue);
    });

    test('les changements des autres utilisateurs arrivent en temps réel',
        () async {
      final c = await connect();
      c.remote.seed(post: remotePost());
      await pumpEventQueue();
      expect(c.provider.getPostById('remote_1'), isNotNull);

      c.remote.seed(reply: remoteReply('r1'));
      await pumpEventQueue();
      // Le nombre de réponses est recalculé côté application.
      expect(c.provider.getPostById('remote_1')!.answersCount, 1);
      expect(c.provider.getAnswersForPost('remote_1').length, 1);
      expect(c.provider.pendingPosts, isEmpty); // réponse d'enseignant
    });

    test("on ne modifie pas la question d'un autre utilisateur", () async {
      final c = await connect();
      c.remote.seed(post: remotePost());
      await pumpEventQueue();

      expect(c.provider.canModifyPost(c.provider.getPostById('remote_1')!),
          isFalse);
      expect(
        c.provider.updatePost('remote_1',
            title: 'Pirate',
            body: 'Tentative de modification',
            courseName: 'Architecture Logicielle'),
        isFalse,
      );
      expect(c.provider.deletePost('remote_1'), isFalse);
      expect(c.remote.calls.where((e) => e.startsWith('delete')), isEmpty);
    });

    test('accepter une réponse met à jour la question sur le serveur',
        () async {
      final c = await connect();
      final id = addQuestion(c.provider);
      await pumpEventQueue();
      c.remote.seed(reply: remoteReply('r1', postId: id));
      await pumpEventQueue();

      expect(c.provider.toggleAcceptAnswer(id, 'r1'), isTrue);
      await pumpEventQueue();
      expect(c.remote.posts[id]!.acceptedReplyId, 'r1');
      expect(c.provider.getPostById(id)!.isResolved, isTrue);

      c.provider.toggleAcceptAnswer(id, 'r1');
      await pumpEventQueue();
      expect(c.remote.calls, contains('setAcceptedReply $id null'));
      expect(c.provider.getPostById(id)!.isResolved, isFalse);
    });

    test("une réponse acceptée supprimée par son auteur rouvre la question",
        () async {
      final c = await connect();
      c.remote.seed(post: remotePost(authorId: 'uid_amel'));
      c.remote.seed(reply: remoteReply('r1'));
      await pumpEventQueue();
      c.provider.toggleAcceptAnswer('remote_1', 'r1');
      await pumpEventQueue();
      expect(c.provider.getPostById('remote_1')!.isResolved, isTrue);

      // L'enseignant supprime sa réponse côté serveur.
      c.remote.replies.remove('r1');
      c.remote.seed();
      await pumpEventQueue();

      final post = c.provider.getPostById('remote_1')!;
      expect(post.acceptedReplyId, isNull);
      expect(post.isResolved, isFalse);
    });

    test('le rôle vient du compte : impossible de le changer à la main',
        () async {
      final c = await connect(user: teacher);
      expect(c.provider.isTeacher, isTrue);

      c.provider.setRole(ForumRole.student);
      expect(c.provider.isTeacher, isTrue);

      // Vérification d'une réponse par l'enseignant connecté.
      c.remote.seed(post: remotePost());
      c.remote.seed(reply: Answer(
        id: 'r2',
        postId: 'remote_1',
        authorId: 'uid_autre',
        authorName: 'Camarade',
        body: 'Réponse à vérifier',
        createdAt: DateTime.now(),
      ));
      await pumpEventQueue();
      c.provider.toggleVerifyAnswer('r2');
      await pumpEventQueue();
      expect(c.remote.replies['r2']!.isTeacherVerified, isTrue);
      expect(c.remote.calls, contains('setReplyVerified r2 true'));
    });

    test("changer de type de réaction remplace l'ancienne", () async {
      final c = await connect();
      final id = addQuestion(c.provider);
      await pumpEventQueue();

      c.provider.toggleReaction(ReactionTarget.post, id, ReactionType.like);
      await pumpEventQueue();
      c.provider.toggleReaction(ReactionTarget.post, id, ReactionType.helpful);
      await pumpEventQueue();

      final key = 'post_${id}_uid_amel';
      expect(c.remote.calls, contains('saveReaction $key replacing=true'));
      expect(c.remote.reactions[key]!.type, ReactionType.helpful);
      expect(c.provider.reactionCount(ReactionTarget.post, id), 1);

      c.provider.toggleReaction(ReactionTarget.post, id, ReactionType.helpful);
      await pumpEventQueue();
      expect(c.remote.reactions, isEmpty);
    });

    test("un refus du serveur est signalé puis effacé à l'écriture suivante",
        () async {
      final c = await connect();
      c.remote.failNext = const ForumRemoteException(
        'Action refusée par les règles de sécurité Firestore.',
        code: 'permission-denied',
      );
      addQuestion(c.provider);
      await pumpEventQueue();
      expect(c.provider.lastSyncError, contains('refusée'));

      addQuestion(c.provider, title: 'Deuxième question');
      await pumpEventQueue();
      expect(c.provider.lastSyncError, isNull);
    });

    test('supprimer une question demande la suppression au serveur', () async {
      final c = await connect();
      final id = addQuestion(c.provider);
      await pumpEventQueue();

      expect(c.provider.deletePost(id), isTrue);
      await pumpEventQueue();
      expect(c.remote.calls, contains('deletePost $id'));
      expect(c.remote.posts, isEmpty);
      expect(c.provider.getPostById(id), isNull);
    });

    test('les notes sont envoyées au serveur et reçues en temps réel',
        () async {
      final c = await connect();
      c.remote.seed(post: remotePost());
      await pumpEventQueue();

      expect(c.provider.rate(ReactionTarget.post, 'remote_1', 4), isTrue);
      await pumpEventQueue();
      const key = 'post_remote_1_uid_amel';
      expect(c.remote.calls, contains('saveRating $key 4'));
      expect(c.provider.ratingStats(ReactionTarget.post, 'remote_1').count, 1);

      // Note d'un autre utilisateur arrivée par le flux temps réel.
      c.remote.seed(
        rating: const Rating(
          targetType: ReactionTarget.post,
          targetId: 'remote_1',
          userId: 'uid_autre2',
          stars: 2,
        ),
      );
      await pumpEventQueue();
      final stats = c.provider.ratingStats(ReactionTarget.post, 'remote_1');
      expect(stats.count, 2);
      expect(stats.average, 3.0);

      c.provider.rate(ReactionTarget.post, 'remote_1', 4); // retrait
      await pumpEventQueue();
      expect(c.remote.calls, contains('deleteRating $key'));
      expect(c.remote.ratings.containsKey(key), isFalse);
    });

    test('la liste des cours reste utilisable sans cours ni question',
        () async {
      final c = await connect();
      expect(c.provider.courses, contains(ForumProvider.generalCourse));
      expect(c.provider.courses.first, ForumProvider.allCourses);
    });

    test('en ligne, le stockage local du mode démonstration est préservé',
        () async {
      final store = MemoryForumStore();
      final provider = makeProvider(store);
      await provider.init();
      final savedBefore = store.saveCount;

      final remote = FakeForumRemote();
      provider.connectRemote(remote, user: student);
      await pumpEventQueue();
      addQuestion(provider);
      await provider.persistenceIdle;

      expect(store.saveCount, savedBefore);
      final snapshot = await store.load();
      expect(snapshot!.posts.length, 4);
    });

    test('la déconnexion restaure les données locales et le profil simulé',
        () async {
      final c = await connect(user: teacher);
      c.remote.seed(post: remotePost());
      await pumpEventQueue();
      expect(c.provider.filteredPosts.length, 1);

      c.provider.disconnectRemote();

      expect(c.provider.isOnline, isFalse);
      expect(c.provider.filteredPosts.length, 4);
      expect(c.provider.currentUser.id, 'user_selim');
      expect(c.provider.isTeacher, isFalse);
    });

    test('le profil connecté peut changer en direct (code enseignant validé)',
        () async {
      final c = await connect();
      expect(c.provider.isTeacher, isFalse);
      c.provider.updateRemoteUser(teacher);
      expect(c.provider.isTeacher, isTrue);
    });
  });
}
