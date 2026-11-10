import 'dart:convert';

import 'package:edulink/services/stack_overflow_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  http.Response json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json; charset=utf-8'});

  StackOverflowService makeService(
    Future<http.Response> Function(http.Request request) handler, {
    String apiKey = 'KEY123',
  }) {
    return StackOverflowService(
      client: MockClient(handler),
      baseUrl: 'http://se.test/2.3',
      apiKey: apiKey,
    );
  }

  const item = {
    'question_id': 42,
    'title': 'How to use &quot;setState&quot; in Flutter&#39;s widgets?',
    'link': 'https://stackoverflow.com/questions/42',
    'score': 12,
    'answer_count': 3,
    'is_answered': true,
    'tags': ['flutter', 'dart'],
  };

  test('envoie la clé, le titre et le tag du langage', () async {
    late Uri requested;
    final service = makeService((request) async {
      requested = request.url;
      return json({'items': [item], 'has_more': false});
    });

    final results = await service.searchSimilar(
      title: 'Comment utiliser setState ?',
      codeLanguage: 'cpp',
    );

    expect(requested.path, '/2.3/search/advanced');
    expect(requested.queryParameters['key'], 'KEY123');
    expect(requested.queryParameters['q'], 'Comment utiliser setState ?');
    expect(requested.queryParameters['tagged'], 'c++');
    expect(requested.queryParameters['site'], 'stackoverflow');
    expect(results, hasLength(1));
    expect(results.first.title, 'How to use "setState" in Flutter\'s widgets?');
    expect(results.first.answerCount, 3);
    expect(results.first.isAnswered, isTrue);
  });

  test('sans clé configurée, le paramètre key est omis', () async {
    late Uri requested;
    final service = makeService((request) async {
      requested = request.url;
      return json({'items': <Object>[]});
    }, apiKey: '');

    await service.searchSimilar(title: 'Un titre assez long pour chercher');
    expect(service.hasKey, isFalse);
    expect(requested.queryParameters.containsKey('key'), isFalse);
    expect(requested.queryParameters.containsKey('tagged'), isFalse);
  });

  test('ignore les titres trop courts sans appeler le réseau', () async {
    var calls = 0;
    final service = makeService((request) async {
      calls++;
      return json({'items': <Object>[]});
    });
    expect(await service.searchSimilar(title: 'court'), isEmpty);
    expect(calls, 0);
  });

  test('met les résultats en cache', () async {
    var calls = 0;
    final service = makeService((request) async {
      calls++;
      return json({'items': [item]});
    });
    await service.searchSimilar(title: 'Une question assez longue');
    await service.searchSimilar(title: 'une QUESTION assez longue');
    expect(calls, 1);
  });

  test('convertit une clé refusée en message lisible', () async {
    final service = makeService((request) async => json({
          'error_id': 403,
          'error_name': 'access_denied',
          'error_message': 'denied',
        }, 400));
    expect(
      () => service.searchSimilar(title: 'Une question assez longue'),
      throwsA(isA<StackOverflowException>()
          .having((e) => e.message, 'message', contains('STACKEXCHANGE_KEY'))),
    );
  });

  test('respecte le champ backoff', () async {
    var calls = 0;
    final service = makeService((request) async {
      calls++;
      return json({'items': <Object>[], 'backoff': 30});
    });
    await service.searchSimilar(title: 'Première recherche assez longue');
    expect(
      () => service.searchSimilar(title: 'Seconde recherche assez longue'),
      throwsA(isA<StackOverflowException>()),
    );
    expect(calls, 1);
  });

  test('decodeHtmlEntities ne décode pas deux fois', () {
    expect(decodeHtmlEntities('a &amp;lt; b &#x41; &#66;'), 'a &lt; b A B');
  });
}
