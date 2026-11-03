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

  test('exécute un programme Python et renvoie la sortie', () async {
    final calls = <String>[];
    Map<String, dynamic>? submitted;
    var polls = 0;

    final service = makeService((request) async {
      calls.add('${request.method} ${request.url.path}');
      if (request.url.path == '/languages') return json(languages);
      if (request.method == 'POST') {
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
      return json({
        'stdout': 'bonjour\n',
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
    expect(submitted!['source_code'], 'print("bonjour")');
    expect(calls.first, 'GET /languages');
    expect(polls, 2);
  });

  test("une erreur d'exécution est renvoyée avec ses messages", () async {
    final service = makeService((request) async {
      if (request.url.path == '/languages') return json(languages);
      if (request.method == 'POST') return json({'token': 't'});
      return json({
        'stderr': 'NameError: x',
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
