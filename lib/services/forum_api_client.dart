import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/answer.dart';
import '../models/post.dart';
import '../models/reaction.dart';
import 'forum_config.dart';
import 'forum_store.dart';

/// Erreur renvoyée par l'API REST du Forum (réseau, délai, statut HTTP).
class ForumApiException implements Exception {
  final String message;
  final int? statusCode;

  const ForumApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Client HTTP de l'API REST du Forum (backend NestJS, un module par membre).
///
/// Endpoints (plan M3) :
/// - `GET /posts/feed`, `POST /posts`, `PATCH|DELETE /posts/:id`
/// - `PATCH /posts/:id/accept/:replyId`, `DELETE /posts/:id/accept`
/// - `GET /replies`, `POST /replies`, `PATCH|DELETE /replies/:id`, `PATCH /replies/:id/verify`
/// - `GET /reactions`, `PUT /reactions`, `DELETE /reactions?targetType=&targetId=&userId=`
class ForumApiClient {
  final ForumConfig config;
  final http.Client _client;

  ForumApiClient({required this.config, http.Client? client})
      : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (config.authToken != null)
          'Authorization': 'Bearer ${config.authToken}',
      };

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('${config.baseUrl}$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } on FormatException {
      // Corps non JSON : on retombe sur le message générique.
    }
    return 'Erreur du serveur (HTTP ${response.statusCode}).';
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final request = http.Request(method, _uri(path, query));
    request.headers.addAll(_headers);
    if (body != null) request.body = jsonEncode(body);

    try {
      final streamed = await _client.send(request).timeout(config.timeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ForumApiException(
          _errorMessage(response),
          statusCode: response.statusCode,
        );
      }
      if (response.bodyBytes.isEmpty) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on TimeoutException {
      throw const ForumApiException('Le serveur ne répond pas (délai dépassé).');
    } on http.ClientException {
      throw const ForumApiException(
          'Serveur injoignable : modification enregistrée localement.');
    } on FormatException {
      throw const ForumApiException('Réponse du serveur illisible.');
    }
  }

  List<T> _items<T>(dynamic decoded, T Function(Map<String, dynamic>) parse) {
    final raw = decoded is Map ? decoded['items'] : decoded;
    if (raw is! List) return <T>[];
    return raw.whereType<Map<String, dynamic>>().map(parse).toList();
  }

  // ------------------------------------------------------------------ Lecture

  /// Récupère les questions, les réponses et les réactions du serveur.
  Future<ForumSnapshot> fetchSnapshot() async {
    final feed = await _send('GET', '/posts/feed', query: {'limit': '500'});
    final replies = await _send('GET', '/replies');
    final reactions = await _send('GET', '/reactions');
    return ForumSnapshot(
      posts: _items(feed, Post.fromJson),
      answers: _items(replies, Answer.fromJson),
      reactions: _items(reactions, Reaction.fromJson),
    );
  }

  // ---------------------------------------------------------------- Questions

  Future<void> createPost(Post post) =>
      _send('POST', '/posts', body: post.toJson());

  Future<void> updatePost(Post post) =>
      _send('PATCH', '/posts/${post.id}', body: post.toJson());

  Future<void> deletePost(String postId) => _send('DELETE', '/posts/$postId');

  Future<void> acceptReply(String postId, String replyId) =>
      _send('PATCH', '/posts/$postId/accept/$replyId');

  Future<void> clearAcceptedReply(String postId) =>
      _send('DELETE', '/posts/$postId/accept');

  // ----------------------------------------------------------------- Réponses

  Future<void> createReply(Answer answer) =>
      _send('POST', '/replies', body: answer.toJson());

  Future<void> updateReply(Answer answer) =>
      _send('PATCH', '/replies/${answer.id}', body: answer.toJson());

  Future<void> deleteReply(String replyId) =>
      _send('DELETE', '/replies/$replyId');

  Future<void> verifyReply(String replyId, {required bool verified}) =>
      _send('PATCH', '/replies/$replyId/verify', body: {'verified': verified});

  // ---------------------------------------------------------------- Réactions

  Future<void> putReaction(Reaction reaction) =>
      _send('PUT', '/reactions', body: reaction.toJson());

  Future<void> deleteReaction(Reaction reaction) => _send(
        'DELETE',
        '/reactions',
        query: {
          'targetType': reaction.targetType.name,
          'targetId': reaction.targetId,
          'userId': reaction.userId,
        },
      );

  void close() => _client.close();
}
