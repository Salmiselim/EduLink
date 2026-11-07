import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Couche de stockage local du module Évaluations basée sur Hive.
///
/// Trois boîtes persistes sont ouvertes au démarrage via [init] :
///   - [_upcomingBox]   → cache des évaluations à venir (liste todo étudiant).
///   - [_gradebookBox]  → cache des lignes du carnet de notes par cours.
///   - [_draftBox]      → brouillons de tentatives en cours (survie au crash app).
///
/// Toutes les entrées sont sérialisées en JSON (`Map → String`) pour éviter
/// l'enregistrement d'adaptateurs Hive générés (compatible avec les contraintes
/// de l'environnement de développement actuel).
class EvaluationsLocalService {
  static const String _upcomingBoxName = 'eval_upcoming';
  static const String _gradebookBoxName = 'eval_gradebook';
  static const String _draftBoxName = 'eval_draft';

  late Box<String> _upcomingBox;
  late Box<String> _gradebookBox;
  late Box<String> _draftBox;

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Initialise Hive et ouvre les boîtes de stockage.
  /// Doit être appelé une seule fois depuis [EvaluationsRepository.init].
  Future<void> init() async {
    await Hive.initFlutter();
    _upcomingBox = await Hive.openBox<String>(_upcomingBoxName);
    _gradebookBox = await Hive.openBox<String>(_gradebookBoxName);
    _draftBox = await Hive.openBox<String>(_draftBoxName);
  }

  // ════════════════════════════════════════════════════════════════════════
  // ÉVALUATIONS À VENIR (upcoming)
  // ════════════════════════════════════════════════════════════════════════

  /// Clé unique : identifiant de l'étudiant.
  static String _upcomingKey(String userId) => 'upcoming_$userId';

  /// Persiste la liste brute des évaluations à venir pour un étudiant.
  Future<void> cacheUpcoming(
    String userId,
    List<Map<String, dynamic>> items,
  ) async {
    await _upcomingBox.put(
      _upcomingKey(userId),
      jsonEncode(items),
    );
  }

  /// Lit le cache des évaluations à venir. Retourne une liste vide si absent.
  List<Map<String, dynamic>> getCachedUpcoming(String userId) {
    final raw = _upcomingBox.get(_upcomingKey(userId));
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  // ════════════════════════════════════════════════════════════════════════
  // CARNET DE NOTES (gradebook)
  // ════════════════════════════════════════════════════════════════════════

  /// Clé unique : identifiant du cours.
  static String _gradebookKey(String courseId) => 'gradebook_$courseId';

  /// Persiste les lignes JSON du carnet de notes d'un cours.
  Future<void> cacheGradebook(
    String courseId,
    List<Map<String, dynamic>> rows,
  ) async {
    await _gradebookBox.put(
      _gradebookKey(courseId),
      jsonEncode(rows),
    );
  }

  /// Lit le cache du carnet de notes. Retourne une liste vide si absent.
  List<Map<String, dynamic>> getCachedGradebook(String courseId) {
    final raw = _gradebookBox.get(_gradebookKey(courseId));
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  // ════════════════════════════════════════════════════════════════════════
  // BROUILLONS DE TENTATIVE (draft answers — survie au crash)
  // ════════════════════════════════════════════════════════════════════════

  /// Clé unique : identifiant de la tentative.
  static String _draftKey(String attemptId) => 'draft_$attemptId';

  /// Sauvegarde les réponses intermédiaires d'une tentative en cours.
  /// Appelé à chaque changement de réponse dans [QuizTakeScreen].
  Future<void> saveDraftAttempt({
    required String attemptId,
    required List<List<int>> answers,
  }) async {
    final payload = {
      'attemptId': attemptId,
      'answers': answers,
      'savedAt': DateTime.now().toIso8601String(),
    };
    await _draftBox.put(_draftKey(attemptId), jsonEncode(payload));
  }

  /// Lit les réponses intermédiaires sauvegardées pour une tentative.
  /// Retourne null si aucun brouillon n'existe (début de session).
  Map<String, dynamic>? getDraftAttempt(String attemptId) {
    final raw = _draftBox.get(_draftKey(attemptId));
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Supprime le brouillon après soumission réussie.
  Future<void> clearDraftAttempt(String attemptId) async {
    await _draftBox.delete(_draftKey(attemptId));
  }

  // ════════════════════════════════════════════════════════════════════════
  // CACHE QUIZ LIST (offline enseignant)
  // ════════════════════════════════════════════════════════════════════════

  static const String _quizListKey = 'quiz_list';

  /// Sauvegarde la liste brute de quiz pour consultation hors-ligne.
  Future<void> cacheQuizList(List<Map<String, dynamic>> quizzes) async {
    await _draftBox.put(_quizListKey, jsonEncode(quizzes));
  }

  /// Lit la liste de quiz en cache. Retourne une liste vide si absent.
  List<Map<String, dynamic>> getCachedQuizList() {
    final raw = _draftBox.get(_quizListKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  /// Supprime un quiz précis du cache local.
  Future<void> removeCachedQuiz(String quizId) async {
    final list = getCachedQuizList().where((q) => q['id'] != quizId).toList();
    await cacheQuizList(list);
  }

  // ════════════════════════════════════════════════════════════════════════
  // UTILITAIRES
  // ════════════════════════════════════════════════════════════════════════

  /// Vide toutes les boîtes de cache (déconnexion ou changement de compte).
  Future<void> clearAll() async {
    await _upcomingBox.clear();
    await _gradebookBox.clear();
    await _draftBox.clear();
  }
}
