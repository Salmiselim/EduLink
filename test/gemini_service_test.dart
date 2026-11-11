import 'dart:convert';

import 'package:edulink/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  http.Response json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json; charset=utf-8'});

  GeminiService makeService(
    Future<http.Response> Function(http.Request request) handler, {
    String apiKey = 'GKEY',
  }) {
    return GeminiService(
      client: MockClient(handler),
      baseUrl: 'http://gemini.test/v1beta',
      model: 'test-model',
      fallbackModels: const ['backup-model'],
      retryDelay: Duration.zero,
      apiKey: apiKey,
    );
  }

  Map<String, dynamic> reply(String text) => {
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': text},
              ],
            },
          },
        ],
      };

  test('appelle generateContent avec la clé dans x-goog-api-key', () async {
    late http.Request sent;
    final service = makeService((request) async {
      sent = request;
      return json(reply('Ce code affiche « é » à l\'écran.'));
    });

    final text = await service.explainCode(
      code: 'print("é")',
      language: 'Python',
      errorOutput: 'NameError: x',
    );

    expect(sent.url.toString(),
        'http://gemini.test/v1beta/models/test-model:generateContent');
    expect(sent.headers['x-goog-api-key'], 'GKEY');
    expect(sent.url.queryParameters.containsKey('key'), isFalse);
    final body = jsonDecode(utf8.decode(sent.bodyBytes)) as Map<String, dynamic>;
    final prompt = (body['contents'] as List).first['parts'].first['text'] as String;
    expect(prompt, contains('Langage : Python'));
    expect(prompt, contains('print("é")'));
    expect(prompt, contains('NameError: x'));
    expect(body['systemInstruction'], isNotNull);
    expect(text, 'Ce code affiche « é » à l\'écran.');
  });

  test('passe au modèle de secours quand le principal est surchargé', () async {
    final urls = <String>[];
    final service = makeService((request) async {
      urls.add(request.url.path);
      if (request.url.path.contains('test-model')) {
        return json({'error': {'status': 'UNAVAILABLE'}}, 503);
      }
      return json(reply('depuis le secours'));
    });

    expect(await service.explainCode(code: 'x = 1'), 'depuis le secours');
    expect(urls, [
      '/v1beta/models/test-model:generateContent',
      '/v1beta/models/backup-model:generateContent',
    ]);
  });

  test('sans clé, refuse sans appeler le réseau', () async {
    var calls = 0;
    final service = makeService((request) async {
      calls++;
      return json(reply('x'));
    }, apiKey: '');

    expect(service.isConfigured, isFalse);
    await expectLater(
      service.explainCode(code: 'print(1)'),
      throwsA(isA<AiAssistantException>()
          .having((e) => e.message, 'message', contains('GEMINI_API_KEY'))),
    );
    expect(calls, 0);
  });

  test('met les explications en cache', () async {
    var calls = 0;
    final service = makeService((request) async {
      calls++;
      return json(reply('ok'));
    });
    await service.explainCode(code: 'a = 1', language: 'Python');
    await service.explainCode(code: 'a = 1', language: 'Python');
    expect(calls, 1);
  });

  test('retire le Markdown et ignore les parties « thought »', () async {
    final service = makeService((request) async => json({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'réflexion interne', 'thought': true},
                  {'text': '**Résumé**\n```python\nprint(1)\n```'},
                ],
              },
            },
          ],
        }));
    final text = await service.explainCode(code: 'print(1)');
    expect(text, 'Résumé\nprint(1)');
  });

  test('traduit les erreurs HTTP en messages lisibles', () async {
    Future<void> expectMessage(int status, Object body, String contains_) async {
      final service = makeService((request) async => json(body, status));
      await expectLater(
        service.explainCode(code: 'x'),
        throwsA(isA<AiAssistantException>()
            .having((e) => e.message, 'message', contains(contains_))),
      );
    }

    await expectMessage(
        400,
        {'error': {'status': 'INVALID_ARGUMENT', 'message': 'API key not valid.'}},
        'GEMINI_API_KEY');
    await expectMessage(
        429, {'error': {'status': 'RESOURCE_EXHAUSTED'}}, 'Quota');
    await expectMessage(503, {'error': {'status': 'UNAVAILABLE'}}, 'surchargé');
  });

  test('réponse bloquée ou vide', () async {
    final service = makeService((request) async => json({
          'promptFeedback': {'blockReason': 'SAFETY'},
        }));
    await expectLater(
      service.explainCode(code: 'x'),
      throwsA(isA<AiAssistantException>()),
    );
  });
}
