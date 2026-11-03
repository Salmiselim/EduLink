import 'dart:convert';

import 'package:edulink/models/answer.dart';
import 'package:edulink/models/post.dart';
import 'package:edulink/models/reaction.dart';
import 'package:edulink/models/user.dart';
import 'package:edulink/services/forum_marketplace_bridge.dart';
import 'package:edulink/services/forum_store.dart';
import 'package:edulink/utils/content_filter.dart';
import 'package:edulink/utils/tag_utils.dart';
import 'package:edulink/utils/time_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatTimeAgo', () {
    final now = DateTime(2026, 11, 1, 12);

    test("« À l'instant » sous une minute ou dans le futur", () {
      expect(formatTimeAgo(now, now: now), "À l'instant");
      expect(formatTimeAgo(now.subtract(const Duration(seconds: 30)), now: now),
          "À l'instant");
      expect(formatTimeAgo(now.add(const Duration(minutes: 5)), now: now),
          "À l'instant");
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

  group('Tags', () {
    test("parseTags normalise, dédoublonne et garde l'ordre", () {
      expect(parseTags('Flutter, #Provider  état;flutter'),
          ['flutter', 'provider', 'état']);
      expect(parseTags('   '), isEmpty);
      expect(parseTags('##dart'), ['dart']);
    });

    test('validateTags contrôle le nombre et la longueur', () {
      expect(validateTags(''), isNull);
      expect(validateTags('flutter, dart'), isNull);
      expect(validateTags('aa bb cc dd ee ff'), contains('Maximum'));
      expect(validateTags('x'), contains('au moins'));
      expect(validateTags('a' * 21), contains('dépasser'));
    });
  });

  group('Filtre de contenu', () {
    test('détecte un mot interdit, avec ou sans accent ou majuscule', () {
      expect(ContentFilter.findViolation('Quel IDIOT !'), 'idiot');
      expect(ContentFilter.findViolation('espèce de crétin'), 'cretin');
      expect(ContentFilter.validate('tu es débile'), isNotNull);
    });

    test('laisse passer un texte correct et les mots qui en contiennent un',
        () {
      expect(ContentFilter.findViolation('Comment utiliser Provider ?'), isNull);
      // « idiotie » n'est pas le mot entier « idiot » : pas de faux positif.
      expect(ContentFilter.validate('Une idiotie de plus'), isNull);
      expect(ContentFilter.validate(''), isNull);
    });
  });

  group('Sérialisation JSON', () {
    test('Post : aller-retour complet', () {
      final post = Post(
        id: 'p1',
        authorId: 'u1',
        authorName: 'Selim',
        courseName: 'Architecture Logicielle',
        title: 'Titre',
        body: 'Corps',
        tags: ['flutter', 'dart'],
        codeSnippet: 'print(1)',
        codeLanguage: 'python',
        status: PostStatus.resolved,
        acceptedReplyId: 'a1',
        answersCount: 3,
        createdAt: DateTime(2026, 11, 1, 9, 30),
        updatedAt: DateTime(2026, 11, 1, 10),
      );

      final copy = Post.fromJson(
          jsonDecode(jsonEncode(post.toJson())) as Map<String, dynamic>);

      expect(copy.id, 'p1');
      expect(copy.tags, ['flutter', 'dart']);
      expect(copy.status, PostStatus.resolved);
      expect(copy.acceptedReplyId, 'a1');
      expect(copy.answersCount, 3);
      expect(copy.codeSnippet, 'print(1)');
      expect(copy.createdAt, post.createdAt);
      expect(copy.updatedAt, post.updatedAt);
    });

    test('Post : lecture tolérante de données incomplètes', () {
      final post = Post.fromJson({'id': 'p2', 'status': 'inconnu'});
      expect(post.title, '');
      expect(post.tags, isEmpty);
      expect(post.status, PostStatus.open);
      expect(post.authorRole, 'student');
    });

    test('Answer : aller-retour complet', () {
      final answer = Answer(
        id: 'a1',
        postId: 'p1',
        authorId: 'u2',
        authorName: 'Sarah',
        authorRole: 'teacher',
        body: 'Réponse',
        codeSnippet: 'x = 1',
        codeLanguage: 'python',
        isTeacherVerified: true,
        verifiedAt: DateTime(2026, 11, 1, 11),
        createdAt: DateTime(2026, 11, 1, 10),
      );

      final copy = Answer.fromJson(
          jsonDecode(jsonEncode(answer.toJson())) as Map<String, dynamic>);

      expect(copy.isTeacher, isTrue);
      expect(copy.isTeacherVerified, isTrue);
      expect(copy.verifiedAt, answer.verifiedAt);
      expect(copy.hasCode, isTrue);
    });

    test('Reaction : identifiant unique par utilisateur et par cible', () {
      const reaction = Reaction(
        targetType: ReactionTarget.reply,
        targetId: 'a1',
        userId: 'u1',
        type: ReactionType.helpful,
      );
      expect(reaction.id, 'reply_a1_u1');

      final copy = Reaction.fromJson(
          jsonDecode(jsonEncode(reaction.toJson())) as Map<String, dynamic>);
      expect(copy.type, ReactionType.helpful);
      expect(copy.id, reaction.id);
    });

    test('ForumSnapshot : aller-retour avec le rôle courant', () {
      final snapshot = ForumSnapshot(
        posts: [
          Post(
            id: 'p1',
            authorName: 'A',
            courseName: 'C',
            title: 'T',
            body: 'B',
            createdAt: DateTime(2026, 11, 1),
          ),
        ],
        answers: const [],
        reactions: const [],
        role: ForumRole.teacher,
      );
      final copy = ForumSnapshot.fromJson(
          jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>);
      expect(copy.role, ForumRole.teacher);
      expect(copy.posts.single.id, 'p1');
    });
  });

  group('Liaison L7 : suggestions du Marketplace', () {
    const bridge = ForumMarketplaceBridge();

    test('propose des offres publiées de la matière du cours', () {
      final offers = bridge.suggestFor(
        courseName: 'Algorithmique & Complexité',
        tags: const [],
      );
      expect(offers, isNotEmpty);
      expect(offers.every((o) => o.subject == 'Algorithmique'), isTrue);
      expect(offers.length, lessThanOrEqualTo(5));
    });

    test('un cours inconnu sans tag ne propose rien', () {
      expect(
        bridge.suggestFor(courseName: 'Cours inexistant', tags: const []),
        isEmpty,
      );
    });
  });
}
