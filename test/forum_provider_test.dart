import 'package:flutter_test/flutter_test.dart';
import 'package:edulink/models/user.dart';
import 'package:edulink/providers/forum_provider.dart';
import 'package:edulink/utils/time_format.dart';

void main() {
  group('ForumProvider - filtres', () {
    test('affiche toutes les questions au départ', () {
      final provider = ForumProvider();
      expect(provider.filteredPosts.length, 3);
      expect(provider.hasActiveFilters, isFalse);
    });

    test('filtre par cours', () {
      final provider = ForumProvider();
      provider.setSelectedCourse('Algorithmique & Complexité');
      expect(provider.filteredPosts.length, 1);
      expect(provider.filteredPosts.first.id, 'post_2');
    });

    test('recherche insensible à la casse, avec espaces ignorés', () {
      final provider = ForumProvider();
      provider.setSearchQuery('  MONGOOSE ');
      expect(provider.filteredPosts.length, 1);
      expect(provider.filteredPosts.first.id, 'post_3');
    });

    test('resetFilters remet tout à zéro', () {
      final provider = ForumProvider();
      provider.setSearchQuery('flutter');
      provider.setSelectedCourse('Architecture Logicielle');
      expect(provider.hasActiveFilters, isTrue);

      provider.resetFilters();
      expect(provider.hasActiveFilters, isFalse);
      expect(provider.filteredPosts.length, 3);
    });
  });

  group('ForumProvider - questions et réponses', () {
    test('createPost ajoute la question en tête et renvoie son id', () {
      final provider = ForumProvider();
      final id = provider.createPost(
        title: '  Nouvelle question  ',
        body: 'Corps de la question',
        courseName: 'Architecture Logicielle',
      );

      expect(provider.filteredPosts.first.id, id);
      expect(provider.getPostById(id)!.title, 'Nouvelle question');
    });

    test('getPostById trouve une question même si un filtre la masque', () {
      final provider = ForumProvider();
      final id = provider.createPost(
        title: 'Question cachée',
        body: 'Corps de la question',
        courseName: 'Architecture Logicielle',
      );
      provider.setSelectedCourse('Algorithmique & Complexité');

      expect(provider.filteredPosts.any((p) => p.id == id), isFalse);
      expect(provider.getPostById(id), isNotNull);
    });

    test('addAnswer incrémente le compteur et ignore un texte vide', () {
      final provider = ForumProvider();
      final before = provider.getPostById('post_3')!.answersCount;

      provider.addAnswer(postId: 'post_3', body: '   ');
      expect(provider.getPostById('post_3')!.answersCount, before);

      provider.addAnswer(postId: 'post_3', body: 'find() renvoie un tableau.');
      expect(provider.getPostById('post_3')!.answersCount, before + 1);
      expect(provider.getAnswersForPost('post_3').length, 1);
    });

    test('toggleVoteAnswer ajoute puis retire le vote', () {
      final provider = ForumProvider();
      final answer = provider.getAnswersForPost('post_1')
          .firstWhere((a) => a.id == 'ans_2');
      final before = answer.votesCount;

      provider.toggleVoteAnswer('ans_2');
      expect(answer.votesCount, before + 1);
      expect(answer.isUpvoted, isTrue);

      provider.toggleVoteAnswer('ans_2');
      expect(answer.votesCount, before);
      expect(answer.isUpvoted, isFalse);
    });
  });

  group('ForumProvider - rôle enseignant', () {
    test('un étudiant ne peut pas vérifier une réponse', () {
      final provider = ForumProvider();
      provider.toggleVerifyAnswer('ans_2');

      final answer = provider.getAnswersForPost('post_1')
          .firstWhere((a) => a.id == 'ans_2');
      expect(answer.isTeacherVerified, isFalse);
    });

    test('un enseignant peut vérifier, et la réponse passe en tête', () {
      final provider = ForumProvider();
      provider.setRole(ForumRole.teacher);
      provider.toggleVerifyAnswer('ans_2');

      final answers = provider.getAnswersForPost('post_1');
      expect(answers.first.id, 'ans_2');
      expect(answers.first.isTeacherVerified, isTrue);
    });

    test('pendingPosts ne contient que les questions sans réponse enseignant', () {
      final provider = ForumProvider();
      expect(provider.pendingPosts.map((p) => p.id), ['post_3']);

      provider.setRole(ForumRole.teacher);
      provider.addAnswer(postId: 'post_3', body: 'find() renvoie un tableau.');
      expect(provider.pendingPosts, isEmpty);
    });

    test('les contenus créés portent le rôle courant', () {
      final provider = ForumProvider();
      provider.setRole(ForumRole.teacher);
      final id = provider.createPost(
        title: 'Annonce',
        body: 'Contenu de annonce',
        courseName: 'Architecture Logicielle',
      );
      expect(provider.getPostById(id)!.isTeacher, isTrue);
    });
  });

  group('formatTimeAgo', () {
    final now = DateTime(2026, 10, 29, 12);

    test("« À l'instant » sous une minute", () {
      expect(formatTimeAgo(now, now: now), "À l'instant");
      expect(
        formatTimeAgo(now.subtract(const Duration(seconds: 30)), now: now),
        "À l'instant",
      );
    });

    test('minutes, heures et jours', () {
      expect(formatTimeAgo(now.subtract(const Duration(minutes: 5)), now: now),
          'Il y a 5 min');
      expect(formatTimeAgo(now.subtract(const Duration(hours: 3)), now: now),
          'Il y a 3 h');
      expect(formatTimeAgo(now.subtract(const Duration(days: 2)), now: now),
          'Il y a 2 j');
    });
  });
}
