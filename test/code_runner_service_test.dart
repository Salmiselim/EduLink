import 'dart:convert';

import 'package:edulink/services/code_runner_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const languages = [
    {'id': 70, 'name': 'Python (2.7.17)'},
    {'id': 71, 'name': 'Python (3.8.1)'},
    {'id': 89, 'name': 'Python (for ML Tasks) (3.7.7)'},
    {'id': 63, 'name': 'JavaScript (Node.js 12.14.0)'},
  ];

  CodeRunnerService makeService(
    Future<http.Response> Function(http.Request request) handler,
  ) {
    return CodeRunnerService(
      client: MockClient(handler),
      baseUrl: 'http://judge.test',
      pollInterval: Duration.zero,
    );
  }

  http.Response json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status);

  /// Encode comme Judge0 : base64 avec des retours à la ligne tous les 20 caractères.
  String judgeBase64(String text) {
    final encoded = base64Encode(utf8.encode(text));
    final buffer = StringBuffer();
    for (var i = 0; i < encoded.length; i += 20) {
      buffer.writeln(encoded.substring(
          i, i + 20 > encoded.length ? encoded.length : i + 20));
    }
    return buffer.toString();
  }

  String decodeBase64(String encoded) => utf8.decode(base64Decode(encoded));

  test('exécute un programme Python et renvoie la sortie', () async {
    final calls = <String>[];
    Map<String, dynamic>? submitted;
    var polls = 0;

    final service = makeService((request) async {
      calls.add('${request.method} ${request.url.path}');
      if (request.url.path == '/languages') return json(languages);
      if (request.method == 'POST') {
        expect(request.url.queryParameters['base64_encoded'], 'true');
        submitted = jsonDecode(request.body) as Map<String, dynamic>;
        return json({'token': 'abc'});
      }
      polls++;
      // 1re interrogation : en cours ; 2e : terminé.
      if (polls == 1) {
        return json({
          'status': {'id': 2, 'description': 'Processing'}
        });
      }
      expect(request.url.queryParameters['base64_encoded'], 'true');
      return json({
        'stdout': judgeBase64('bonjour\n'),
        'status': {'id': 3, 'description': 'Accepted'},
        'time': '0.012',
      });
    });

    final result = await service.run(
      language: CodeRunnerService.languageByKey('python')!,
      source: 'print("bonjour")',
    );

    expect(result.success, isTrue);
    expect(result.stdout, 'bonjour\n');
    expect(result.time, '0.012');
    expect(result.statusLabel, 'Accepted');
    // Python 3.8.1 (id 71) est choisi : ni la 2.7 ni la variante « ML ».
    expect(submitted!['language_id'], 71);
    expect(decodeBase64(submitted!['source_code'] as String), 'print("bonjour")');
    expect(submitted!.containsKey('stdin'), isFalse);
    expect(calls.first, 'GET /languages');
    expect(polls, 2);
  });

  test("une erreur d'exécution est renvoyée avec ses messages", () async {
    final service = makeService((request) async {
      if (request.url.path == '/languages') return json(languages);
      if (request.method == 'POST') return json({'token': 't'});
      return json({
        'stderr': judgeBase64('NameError: x'),
        'status': {'id': 11, 'description': 'Runtime Error (NZEC)'},
      });
    });

    final result = await service.run(
      language: CodeRunnerService.languageByKey('python')!,
      source: 'print(x)',
    );
    expect(result.success, isFalse);
    expect(result.stderr, 'NameError: x');
    expect(result.hasOutput, isTrue);
  });

  test('un code avec des accents est envoyé et reçu sans erreur (UTF-8)',
      () async {
    const source = 'print("Résultat final : 15 ✓")';
    Map<String, dynamic>? submitted;
    final service = makeService((request) async {
      if (request.url.path == '/languages') return json(languages);
      if (request.method == 'POST') {
        submitted = jsonDecode(request.body) as Map<String, dynamic>;
        return json({'token': 't'});
      }
      return json({
        'stdout': judgeBase64('Résultat final : 15 ✓\n'),
        'status': {'id': 3, 'description': 'Accepted'},
      });
    });

    final result = await service.run(
      language: CodeRunnerService.languageByKey('python')!,
      source: source,
    );
    expect(decodeBase64(submitted!['source_code'] as String), source);
    expect(result.stdout, 'Résultat final : 15 ✓\n');
    expect(result.success, isTrue);
  });

  test("une entrée standard est envoyée en base64", () async {
    Map<String, dynamic>? submitted;
    final service = makeService((request) async {
      if (request.url.path == '/languages') return json(languages);
      if (request.method == 'POST') {
        submitted = jsonDecode(request.body) as Map<String, dynamic>;
        return json({'token': 't'});
      }
      return json({
        'status': {'id': 3, 'description': 'Accepted'}
      });
    });
    await service.run(
      language: CodeRunnerService.languageByKey('python')!,
      source: 'print(input())',
      stdin: 'salut',
    );
    expect(decodeBase64(submitted!['stdin'] as String), 'salut');
  });

  test('refuse un langage non exécutable ou un code vide', () async {
    final service = makeService((_) async => json(languages));

    await expectLater(
      service.run(
        language: CodeRunnerService.languageByKey('dart')!,
        source: 'void main() {}',
      ),
      throwsA(isA<CodeRunException>()),
    );
    await expectLater(
      service.run(
        language: CodeRunnerService.languageByKey('python')!,
        source: '   ',
      ),
      throwsA(isA<CodeRunException>()),
    );
  });

  test("signale un langage absent du service d'exécution", () async {
    final service = makeService((_) async => json(languages));
    await expectLater(
      service.run(
        language: CodeRunnerService.languageByKey('rust')!,
        source: 'fn main() {}',
      ),
      throwsA(isA<CodeRunException>()
          .having((e) => e.message, 'message', contains('Rust'))),
    );
  });

  test('convertit les erreurs HTTP en messages lisibles', () async {
    Future<void> expectMessage(int status, String fragment) async {
      final service = makeService((_) async => http.Response('', status));
      await expectLater(
        service.run(
          language: CodeRunnerService.languageByKey('python')!,
          source: 'print(1)',
        ),
        throwsA(isA<CodeRunException>()
            .having((e) => e.message, 'message', contains(fragment))),
      );
    }

    await expectMessage(429, "Trop d'exécutions");
    await expectMessage(403, 'sans clé');
    await expectMessage(500, 'HTTP 500');
    await expectMessage(400, 'HTTP 400');
  });

  test("le message d'erreur du service est repris dans l'affichage", () async {
    final service = makeService((request) async {
      if (request.url.path == '/languages') return json(languages);
      return json({'error': 'language_id is invalid'}, 422);
    });
    await expectLater(
      service.run(
        language: CodeRunnerService.languageByKey('python')!,
        source: 'print(1)',
      ),
      throwsA(isA<CodeRunException>()
          .having((e) => e.message, 'message', contains('language_id is invalid'))),
    );
  });

  test('signale un service injoignable', () async {
    final service =
        makeService((_) async => throw http.ClientException('hors ligne'));
    await expectLater(
      service.run(
        language: CodeRunnerService.languageByKey('python')!,
        source: 'print(1)',
      ),
      throwsA(isA<CodeRunException>()
          .having((e) => e.message, 'message', contains('injoignable'))),
    );
  });

  test("abandonne si l'exécution ne se termine jamais", () async {
    final service = CodeRunnerService(
      client: MockClient((request) async {
        if (request.url.path == '/languages') return json(languages);
        if (request.method == 'POST') return json({'token': 't'});
        return json({
          'status': {'id': 2, 'description': 'Processing'}
        });
      }),
      baseUrl: 'http://judge.test',
      pollInterval: Duration.zero,
      maxPolls: 3,
    );
    await expectLater(
      service.run(
        language: CodeRunnerService.languageByKey('python')!,
        source: 'while True: pass',
      ),
      throwsA(isA<CodeRunException>()
          .having((e) => e.message, 'message', contains('trop de temps'))),
    );
  });
}
