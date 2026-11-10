import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'forum_config.dart';

/// Question Stack Overflow proposée comme « question similaire ».
class StackQuestion {
  final int id;
  final String title;
  final String link;
  final int score;
  final int answerCount;
  final bool isAnswered;
  final List<String> tags;

  const StackQuestion({
    required this.id,
    required this.title,
    required this.link,
    this.score = 0,
    this.answerCount = 0,
    this.isAnswered = false,
    this.tags = const [],
  });

  /// Construit une question à partir d'un élément `items[]` de l'API.
  /// Les titres sont renvoyés encodés en HTML (`&#39;`, `&quot;`...) : on les décode.
  factory StackQuestion.fromJson(Map<String, dynamic> json) {
    return StackQuestion(
      id: (json['question_id'] as num?)?.toInt() ?? 0,
      title: decodeHtmlEntities((json['title'] as String?) ?? ''),
      link: (json['link'] as String?) ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      answerCount: (json['answer_count'] as num?)?.toInt() ?? 0,
      isAnswered: json['is_answered'] == true,
      tags: [
        for (final tag in (json['tags'] as List?) ?? const [])
          if (tag is String) tag,
      ],
    );
  }
}

/// Erreur du service Stack Exchange (réseau, quota, requête refusée).
class StackOverflowException implements Exception {
  final String message;
  const StackOverflowException(this.message);

  @override
  String toString() => message;
}

/// Décode les entités HTML renvoyées par l'API Stack Exchange.
String decodeHtmlEntities(String text) {
  const named = {
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
    '&lt;': '<',
    '&gt;': '>',
    '&nbsp;': ' ',
  };
  var out = text;
  named.forEach((entity, value) => out = out.replaceAll(entity, value));
  out = out.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
    return String.fromCharCode(int.parse(m.group(1)!, radix: 16));
  });
  out = out.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    return String.fromCharCode(int.parse(m.group(1)!));
  });
  // `&amp;` en dernier pour ne pas décoder deux fois (`&amp;lt;` -> `&lt;`).
  return out.replaceAll('&amp;', '&');
}

/// Recherche des questions proches sur Stack Overflow via l'API Stack Exchange 2.3.
///
/// Appel : `GET /search/advanced?q=<titre>&tagged=<langage>&site=stackoverflow`.
/// La clé d'application (`key`) est ajoutée à chaque requête quand elle est
/// configurée : elle identifie l'application et porte le quota de 300 à 10 000
/// requêtes par jour. Le service respecte aussi le champ `backoff` renvoyé par
/// l'API (pause imposée entre deux requêtes) et garde en mémoire les recherches
/// déjà faites pour économiser le quota.
class StackOverflowService {
  /// Langage du Forum (`CodeLanguage.key`) -> tag Stack Overflow équivalent.
  static const Map<String, String> languageTags = {
    'python': 'python',
    'javascript': 'javascript',
    'typescript': 'typescript',
    'java': 'java',
    'c': 'c',
    'cpp': 'c++',
    'go': 'go',
    'rust': 'rust',
    'php': 'php',
    'ruby': 'ruby',
    'bash': 'bash',
    'dart': 'dart',
  };

  /// Longueur minimale du titre avant de lancer une recherche.
  static const int minQueryLength = 12;

  final String baseUrl;
  final String apiKey;
  final int pageSize;
  final Duration timeout;
  final http.Client _client;
  final Map<String, List<StackQuestion>> _cache = {};
  DateTime? _blockedUntil;

  StackOverflowService({
    http.Client? client,
    this.baseUrl = ForumConfig.stackExchangeBaseUrl,
    this.apiKey = ForumConfig.stackExchangeKey,
    this.pageSize = 5,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  /// Vrai quand une clé d'application est configurée.
  bool get hasKey => apiKey.isNotEmpty;

  /// Questions Stack Overflow ressemblant à [title] (au plus [pageSize]).
  /// [codeLanguage] (clé du Forum) restreint la recherche au tag correspondant.
  Future<List<StackQuestion>> searchSimilar({
    required String title,
    String? codeLanguage,
  }) async {
    final query = title.trim();
    if (query.length < minQueryLength) return const [];

    final tag = languageTags[codeLanguage];
    final cacheKey = '${tag ?? ''}|${query.toLowerCase()}';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final blockedUntil = _blockedUntil;
    if (blockedUntil != null && DateTime.now().isBefore(blockedUntil)) {
      throw const StackOverflowException(
          'Stack Overflow demande de patienter quelques secondes.');
    }

    final uri = Uri.parse('$baseUrl/search/advanced').replace(
      queryParameters: {
        'order': 'desc',
        'sort': 'relevance',
        'q': query,
        'answers': '1', // au moins une réponse : suggestions utiles
        'site': 'stackoverflow',
        'pagesize': '$pageSize',
        if (tag != null) 'tagged': tag,
        if (hasKey) 'key': apiKey,
      },
    );

    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(timeout);
    } on TimeoutException {
      throw const StackOverflowException(
          'Stack Overflow ne répond pas. Réessayez dans un instant.');
    } catch (_) {
      throw const StackOverflowException(
          'Impossible de joindre Stack Overflow (vérifiez la connexion).');
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    } on FormatException {
      throw StackOverflowException(
          'Réponse illisible de Stack Overflow (HTTP ${response.statusCode}).');
    }
    if (decoded is! Map) {
      throw const StackOverflowException('Réponse inattendue de Stack Overflow.');
    }

    // En cas d'erreur, l'API renvoie error_id / error_name / error_message.
    if (response.statusCode != 200 || decoded['error_id'] != null) {
      final name = decoded['error_name'];
      if (name == 'throttle_violation') {
        throw const StackOverflowException(
            "Trop de requêtes vers Stack Overflow, réessayez plus tard.");
      }
      if (name == 'access_denied' || name == 'invalid_key') {
        throw const StackOverflowException(
            'Clé Stack Exchange refusée : vérifiez STACKEXCHANGE_KEY.');
      }
      throw StackOverflowException(
          'Stack Overflow a refusé la requête (HTTP ${response.statusCode}).');
    }

    final backoff = (decoded['backoff'] as num?)?.toInt();
    if (backoff != null && backoff > 0) {
      _blockedUntil = DateTime.now().add(Duration(seconds: backoff));
    }

    final items = decoded['items'];
    final results = <StackQuestion>[
      if (items is List)
        for (final item in items)
          if (item is Map<String, dynamic>) StackQuestion.fromJson(item),
    ].where((q) => q.title.isNotEmpty && q.link.isNotEmpty).toList();

    _cache[cacheKey] = results;
    return results;
  }

  void close() => _client.close();
}
