import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/answer.dart';
import '../models/post.dart';
import '../models/rating.dart';
import '../models/reaction.dart';
import '../models/user.dart';

List<T> _readList<T>(Object? raw, T Function(Map<String, dynamic>) parse) {
  if (raw is! List) return <T>[];
  return raw.whereType<Map<String, dynamic>>().map(parse).toList();
}

/// Instantané complet de l'état du Forum : questions, réponses, réactions et rôle courant.
class ForumSnapshot {
  final List<Post> posts;
  final List<Answer> answers;
  final List<Reaction> reactions;
  final List<Rating> ratings;
  final ForumRole role;

  const ForumSnapshot({
    required this.posts,
    required this.answers,
    required this.reactions,
    this.ratings = const [],
    this.role = ForumRole.student,
  });

  Map<String, dynamic> toJson() => {
        'version': 1,
        'role': role.name,
        'posts': posts.map((p) => p.toJson()).toList(),
        'answers': answers.map((a) => a.toJson()).toList(),
        'reactions': reactions.map((r) => r.toJson()).toList(),
        'ratings': ratings.map((r) => r.toJson()).toList(),
      };

  factory ForumSnapshot.fromJson(Map<String, dynamic> json) {
    final roleName = json['role'];
    return ForumSnapshot(
      posts: _readList(json['posts'], Post.fromJson),
      answers: _readList(json['answers'], Answer.fromJson),
      reactions: _readList(json['reactions'], Reaction.fromJson),
      ratings: _readList(json['ratings'], Rating.fromJson),
      role: roleName == ForumRole.teacher.name
          ? ForumRole.teacher
          : ForumRole.student,
    );
  }
}

/// Stockage local du Forum (contrat). Implémenté par [SharedPrefsForumStore]
/// en production et par [MemoryForumStore] dans les tests.
abstract class ForumStore {
  /// Charge le dernier instantané enregistré, ou null s'il n'y en a pas.
  Future<ForumSnapshot?> load();

  /// Enregistre l'instantané (remplace le précédent).
  Future<void> save(ForumSnapshot snapshot);

  /// Efface toutes les données locales du Forum.
  Future<void> clear();
}

/// Stockage sur l'appareil via SharedPreferences : tout le Forum est
/// sérialisé en un seul document JSON sous la clé [storageKey].
class SharedPrefsForumStore implements ForumStore {
  static const String storageKey = 'edulink_forum_v1';

  @override
  Future<ForumSnapshot?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return ForumSnapshot.fromJson(decoded);
      }
    } on FormatException {
      // Données corrompues : on repart des données d'exemple.
    }
    return null;
  }

  @override
  Future<void> save(ForumSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(snapshot.toJson()));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}

/// Stockage en mémoire (tests unitaires). Passe par JSON pour reproduire
/// exactement le comportement de la sérialisation réelle.
class MemoryForumStore implements ForumStore {
  String? _raw;

  /// Nombre d'enregistrements effectués (utile pour les tests).
  int saveCount = 0;

  @override
  Future<ForumSnapshot?> load() async {
    final raw = _raw;
    if (raw == null) return null;
    return ForumSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(ForumSnapshot snapshot) async {
    _raw = jsonEncode(snapshot.toJson());
    saveCount++;
  }

  @override
  Future<void> clear() async {
    _raw = null;
  }
}
