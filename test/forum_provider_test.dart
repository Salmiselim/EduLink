import 'dart:convert';

import 'package:edulink/models/post.dart';
import 'package:edulink/models/reaction.dart';
import 'package:edulink/models/user.dart';
import 'package:edulink/providers/forum_provider.dart';
import 'package:edulink/services/forum_api_client.dart';
import 'package:edulink/services/forum_config.dart';
import 'package:edulink/services/forum_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
    ForumProvider(store: store ?? MemoryForumStore());

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

  group('Synchronisation REST (client HTTP simulé)', () {
    ({ForumProvider provider, List<http.Request> calls}) makeRemote(
      Future<http.Response> Function(http.Request request) handler,
    ) {
      final calls = <http.Request>[];
      final client = MockClient((request) async {
        calls.add(request);
        return handler(request);
      });
      final api = ForumApiClient(
        config: const ForumConfig(
            remoteEnabled: true, baseUrl: 'http://test.local'),
        client: client,
      );
      return (
        provider: ForumProvider(store: MemoryForumStore(), api: api),
        calls: calls,
      );
    }

    test('chaque opération envoie la bonne requête', () async {
      final remote = makeRemote((_) async => http.Response('{}', 200));
      final provider = remote.provider;

      final id = addQuestion(provider);
      await pumpEventQueue();
      provider.updatePost(id,
          title: 'Titre modifié',
          body: 'Corps modifié de la question',
          courseName: 'Architecture Logicielle');
      await pumpEventQueue();
      provider.toggleReaction(ReactionTarget.post, id, ReactionType.like);
      await pumpEventQueue();
      provider.toggleReaction(ReactionTarget.post, id, ReactionType.like);
      await pumpEventQueue();
      final answerId = provider.addAnswer(postId: id, body: 'Une réponse')!;
      await pumpEventQueue();
      provider.deleteAnswer(answerId);
      await pumpEventQueue();
      provider.deletePost(id);
      await pumpEventQueue();

      final summary =
          remote.calls.map((c) => '${c.method} ${c.url.path}').toList();
      expect(summary, [
        'POST /posts',
        'PATCH /posts/$id',
        'PUT /reactions',
        'DELETE /reactions',
        'POST /replies',
        'DELETE /replies/$answerId',
        'DELETE /posts/$id',
      ]);

      // Le corps de la création contient bien la question en JSON.
      final created =
          jsonDecode(remote.calls.first.body) as Map<String, dynamic>;
      expect(created['id'], id);
      expect(created['courseName'], 'Architecture Logicielle');
      expect(remote.calls[3].url.queryParameters['userId'], 'user_selim');
      expect(provider.lastSyncError, isNull);
    });

    test('une erreur du serveur est mémorisée sans perdre la donnée locale',
        () async {
      final remote = makeRemote(
        (_) async => http.Response('{"message":"Serveur en panne"}', 500),
      );
      final id = addQuestion(remote.provider);
      await pumpEventQueue();

      expect(remote.provider.lastSyncError, 'Serveur en panne');
      expect(remote.provider.getPostById(id), isNotNull);
    });

    test('un serveur injoignable est signalé', () async {
      final remote =
          makeRemote((_) async => throw http.ClientException('hors ligne'));
      addQuestion(remote.provider);
      await pumpEventQueue();
      expect(remote.provider.lastSyncError, contains('injoignable'));
    });

    test('refresh fusionne les données du serveur sans rien supprimer',
        () async {
      final remotePost = Post(
        id: 'remote_1',
        authorId: 'user_x',
        authorName: 'Distant',
        courseName: 'Architecture Logicielle',
        title: 'Question venue du serveur',
        body: 'Corps de la question distante',
        createdAt: DateTime.now(),
      );
      final remote = makeRemote((request) async {
        if (request.url.path == '/posts/feed') {
          return http.Response(
            jsonEncode({
              'items': [remotePost.toJson()]
            }),
            200,
          );
        }
        return http.Response('{"items":[]}', 200);
      });

      await remote.provider.refresh();

      expect(remote.provider.getPostById('remote_1')!.title,
          'Question venue du serveur');
      expect(remote.provider.filteredPosts.length, 5);
      expect(remote.provider.lastSyncError, isNull);
    });

    test('un refresh en échec garde les données locales', () async {
      final remote = makeRemote((_) async => http.Response('oups', 503));
      await remote.provider.refresh();

      expect(remote.provider.lastSyncError, isNotNull);
      expect(remote.provider.filteredPosts.length, 4);
    });
  });
}
