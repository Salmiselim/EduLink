import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'forum_config.dart';

/// Langage proposé pour les extraits de code du Forum.
class CodeLanguage {
  /// Clé stockée dans `Post.codeLanguage` / `Answer.codeLanguage`.
  final String key;

  /// Libellé affiché dans l'interface.
  final String label;

  /// Début du nom du langage chez Judge0 (ex. « Python ( »), null si non exécutable.
  final String? judgePrefix;

  const CodeLanguage(this.key, this.label, [this.judgePrefix]);

  bool get runnable => judgePrefix != null;
}

/// Résultat d'exécution d'un extrait de code.
class CodeRunResult {
  final bool success;
  final String statusLabel;
  final String stdout;
  final String stderr;
  final String compileOutput;
  final String message;
  final String? time;

  const CodeRunResult({
    required this.success,
    required this.statusLabel,
    this.stdout = '',
    this.stderr = '',
    this.compileOutput = '',
    this.message = '',
    this.time,
  });

  factory CodeRunResult.fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    final statusMap = status is Map ? status : const <String, dynamic>{};
    return CodeRunResult(
      success: (statusMap['id'] as num?)?.toInt() == 3,
      statusLabel: (statusMap['description'] as String?) ?? '',
      stdout: (json['stdout'] as String?) ?? '',
      stderr: (json['stderr'] as String?) ?? '',
      compileOutput: (json['compile_output'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      time: json['time']?.toString(),
    );
  }

  /// Sortie standard, ou erreurs si l'exécution a échoué.
  bool get hasOutput =>
      stdout.isNotEmpty ||
      stderr.isNotEmpty ||
      compileOutput.isNotEmpty ||
      message.isNotEmpty;
}

/// Erreur du service d'exécution (réseau, quota, langage indisponible).
class CodeRunException implements Exception {
  final String message;
  const CodeRunException(this.message);

  @override
  String toString() => message;
}

/// Exécute un extrait de code via l'API publique Judge0 CE (HTTP).
///
/// Flux : `GET /languages` (identifiant du langage) -> `POST /submissions`
/// (jeton) -> `GET /submissions/:jeton` jusqu'à la fin du traitement.
/// Le code et les sorties sont échangés en base64 (`base64_encoded=true`) :
/// en texte brut, Judge0 refuse (HTTP 400) tout code ou toute sortie contenant
/// des caractères non ASCII (accents, symboles).
/// L'API publique est gratuite mais limitée et peut changer : toute erreur est
/// convertie en [CodeRunException] avec un message lisible.
class CodeRunnerService {
  /// Langages proposés dans les formulaires. `dart` n'est pas exécutable ici.
  static const List<CodeLanguage> languages = [
    CodeLanguage('python', 'Python', 'Python ('),
    CodeLanguage('javascript', 'JavaScript', 'JavaScript ('),
    CodeLanguage('typescript', 'TypeScript', 'TypeScript ('),
    CodeLanguage('java', 'Java', 'Java ('),
    CodeLanguage('c', 'C', 'C ('),
    CodeLanguage('cpp', 'C++', 'C++ ('),
    CodeLanguage('go', 'Go', 'Go ('),
    CodeLanguage('rust', 'Rust', 'Rust ('),
    CodeLanguage('php', 'PHP', 'PHP ('),
    CodeLanguage('ruby', 'Ruby', 'Ruby ('),
    CodeLanguage('bash', 'Bash', 'Bash ('),
    CodeLanguage('dart', 'Dart'),
    CodeLanguage('text', 'Texte / autre'),
  ];

  /// Retrouve un langage par sa clé (null si inconnue).
  static CodeLanguage? languageByKey(String? key) {
    for (final language in languages) {
      if (language.key == key) return language;
    }
    return null;
  }

  final String baseUrl;
  final Duration timeout;
  final Duration pollInterval;
  final int maxPolls;
  final http.Client _client;
  List<({int id, String name})>? _judgeLanguages;

  CodeRunnerService({
    http.Client? client,
    this.baseUrl = ForumConfig.judge0BaseUrl,
    this.timeout = const Duration(seconds: 15),
    this.pollInterval = const Duration(milliseconds: 900),
    this.maxPolls = 12,
  }) : _client = client ?? http.Client();

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    try {
      final streamed = await _client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      final code = response.statusCode;
      if (code == 429) {
        throw const CodeRunException(
            "Trop d'exécutions pour le moment, réessayez dans un instant.");
      }
      if (code == 401 || code == 403) {
        throw const CodeRunException(
            "Le service d'exécution public refuse les requêtes sans clé.");
      }
      if (code == 400 || code == 422) {
        throw CodeRunException(
            "Requête refusée par le service d'exécution (HTTP $code)${_detail(response)}.");
      }
      if (code < 200 || code >= 300) {
        throw CodeRunException("Service d'exécution indisponible (HTTP $code).");
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on TimeoutException {
      throw const CodeRunException("Le service d'exécution ne répond pas.");
    } on http.ClientException {
      throw const CodeRunException(
          "Service d'exécution injoignable : vérifiez votre connexion Internet.");
    } on FormatException {
      throw const CodeRunException("Réponse du service d'exécution illisible.");
    }
  }

  /// Message d'erreur renvoyé par le service (tronqué), précédé de « : », ou vide.
  String _detail(http.Response response) {
    var text = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        final message = decoded['error'] ?? decoded['message'];
        if (message is String) {
          text = message;
        } else if (decoded.isNotEmpty) {
          text = decoded.values.join(' ');
        }
      }
    } on FormatException {
      // Corps non JSON : on garde le texte brut.
    }
    if (text.isEmpty) return '';
    return ' : ${text.length > 140 ? '${text.substring(0, 140)}...' : text}';
  }

  static String _toBase64(String text) => base64Encode(utf8.encode(text));

  /// Décode un champ base64 de Judge0 (qui insère des retours à la ligne) ;
  /// renvoie le texte tel quel s'il n'est pas du base64 valide.
  static String _fromBase64(String raw) {
    try {
      return utf8.decode(
        base64.decode(raw.replaceAll(RegExp(r'\s'), '')),
        allowMalformed: true,
      );
    } on FormatException {
      return raw;
    }
  }

  /// Décode les champs texte d'une soumission terminée (sorties et messages).
  Map<String, dynamic> _decodeTextFields(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    for (final key in const ['stdout', 'stderr', 'compile_output', 'message']) {
      final raw = copy[key];
      if (raw is String) copy[key] = _fromBase64(raw);
    }
    return copy;
  }

  /// Identifiant Judge0 du langage (la version la plus récente disponible).
  Future<int?> _resolveLanguageId(CodeLanguage language) async {
    var available = _judgeLanguages;
    if (available == null) {
      final decoded = await _request('GET', '/languages');
      available = <({int id, String name})>[];
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map && item['id'] is num && item['name'] is String) {
            available.add((
              id: (item['id'] as num).toInt(),
              name: item['name'] as String,
            ));
          }
        }
      }
      _judgeLanguages = available;
    }

    final prefix = language.judgePrefix;
    if (prefix == null) return null;
    final matches = available
        .where((l) => l.name.startsWith(prefix) && !l.name.contains('ML'))
        .toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    return matches.isEmpty ? null : matches.first.id;
  }

  int _statusIdOf(Map<String, dynamic> json) {
    final status = json['status'];
    if (status is Map) return (status['id'] as num?)?.toInt() ?? 0;
    return 0;
  }

  /// Exécute [source] et renvoie le résultat (sortie, erreurs, durée).
  Future<CodeRunResult> run({
    required CodeLanguage language,
    required String source,
    String stdin = '',
  }) async {
    if (!language.runnable) {
      throw CodeRunException(
          "Le langage « ${language.label} » ne peut pas être exécuté ici.");
    }
    if (source.trim().isEmpty) {
      throw const CodeRunException('Aucun code à exécuter.');
    }

    final languageId = await _resolveLanguageId(language);
    if (languageId == null) {
      throw CodeRunException(
          "Le service d'exécution ne propose pas ${language.label}.");
    }

    final created = await _request(
      'POST',
      '/submissions?base64_encoded=true&wait=false',
      body: {
        'source_code': _toBase64(source),
        'language_id': languageId,
        if (stdin.isNotEmpty) 'stdin': _toBase64(stdin),
      },
    );
    final token = created is Map ? created['token'] as String? : null;
    if (token == null) {
      throw const CodeRunException("Le service d'exécution n'a pas renvoyé de jeton.");
    }

    for (var attempt = 0; attempt < maxPolls; attempt++) {
      if (pollInterval > Duration.zero) await Future<void>.delayed(pollInterval);
      final decoded = await _request(
        'GET',
        '/submissions/$token?base64_encoded=true'
        '&fields=stdout,stderr,compile_output,message,status,time,memory',
      );
      if (decoded is! Map<String, dynamic>) {
        throw const CodeRunException("Réponse du service d'exécution illisible.");
      }
      // 1 = en file d'attente, 2 = en cours : on continue d'attendre.
      if (_statusIdOf(decoded) > 2) {
        return CodeRunResult.fromJson(_decodeTextFields(decoded));
      }
    }
    throw const CodeRunException("L'exécution prend trop de temps.");
  }

  void close() => _client.close();
}
