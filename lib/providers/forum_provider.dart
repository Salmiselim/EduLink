import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/mock_forum_data.dart';
import '../models/answer.dart';
import '../models/post.dart';
import '../models/reaction.dart';
import '../models/user.dart';
import '../services/code_runner_service.dart';
import '../services/forum_api_client.dart';
import '../services/forum_config.dart';
import '../services/forum_store.dart';
import '../utils/tag_utils.dart';

/// Filtre sur l'état des questions dans le fil.
enum ForumStatusFilter { all, unanswered, resolved }

/// Gestionnaire d'état central du Forum basé sur `ChangeNotifier`.
///
/// Source de vérité en mémoire des questions (`Post`), réponses (`Answer`) et
/// réactions (`Reaction`). Chaque modification est :
/// 1. appliquée en mémoire puis notifiée aux écrans (`notifyListeners`) ;
/// 2. enregistrée sur l'appareil via [ForumStore] (SharedPreferences) ;
/// 3. envoyée au backend REST via [ForumApiClient] si la synchro est activée.
class ForumProvider with ChangeNotifier {
  /// Libellé représentant l'absence de filtre sur un cours particulier.
  static const String allCourses = 'Tous les cours';

  /// Nombre de questions affichées par page dans le fil.
  static const int pageSize = 10;

  // Profils simulés permettant de tester les droits étudiant et enseignant localement.
  static const ForumUser _testStudent = ForumUser(
    id: 'user_selim',
    name: 'Selim Riahi',
    role: ForumRole.student,
  );
  static const ForumUser _testTeacher = ForumUser(
    id: 'user_sarah',
    name: 'Dr. Sarah Mansour',
    role: ForumRole.teacher,
    title: 'Enseignante',
  );

  final ForumStore _store;
  final ForumApiClient? _api;

  /// Service d'exécution de code (Judge0), utilisé par `ForumCodeBlock`.
  final CodeRunnerService codeRunner;

  final List<Post> _posts = [];
  final List<Answer> _answers = [];
  final List<Reaction> _reactions = [];

  String _searchQuery = '';
  String _selectedCourse = allCourses;
  ForumStatusFilter _statusFilter = ForumStatusFilter.all;
  String? _tagFilter;
  int _visibleCount = pageSize;

  ForumUser _currentUser = _testStudent;
  int _idCounter = 0;
  bool _isReady = false;
  bool _disposed = false;
  String? _lastSyncError;
  Future<void> _saveChain = Future<void>.value();

  ForumProvider({
    ForumStore? store,
    ForumApiClient? api,
    CodeRunnerService? codeRunner,
    ForumConfig config = ForumConfig.fromEnv,
  })  : _store = store ?? SharedPrefsForumStore(),
        _api = api ?? (config.remoteEnabled ? ForumApiClient(config: config) : null),
        codeRunner = codeRunner ?? CodeRunnerService() {
    _posts.addAll(MockForumData.getInitialPosts());
    _answers.addAll(MockForumData.getInitialAnswers());
    _reactions.addAll(MockForumData.getInitialReactions());
    _sortPosts();
  }

  // ================================================================= Cycle de vie

  /// Charge les données enregistrées sur l'appareil (ou enregistre les données
  /// d'exemple au premier lancement), puis synchronise avec le serveur si activé.
  Future<void> init() async {
    try {
      final snapshot = await _store.load();
      if (snapshot != null) {
        _applySnapshot(snapshot);
      } else {
        await _store.save(_snapshot());
      }
    } catch (error) {
      debugPrint('Forum : stockage local indisponible ($error)');
    }
    _isReady = true;
    _notify();
    if (_api != null) unawaited(refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    _api?.close();
    codeRunner.close();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Vrai une fois le chargement initial du stockage local terminé.
  bool get isReady => _isReady;

  /// Termine quand tous les enregistrements locaux en attente sont écrits.
  Future<void> get persistenceIdle => _saveChain;

  // =================================================================== Stockage

  ForumSnapshot _snapshot() => ForumSnapshot(
        posts: List<Post>.of(_posts),
        answers: List<Answer>.of(_answers),
        reactions: List<Reaction>.of(_reactions),
        role: _currentUser.role,
      );

  void _applySnapshot(ForumSnapshot snapshot) {
    _posts
      ..clear()
      ..addAll(snapshot.posts);
    _answers
      ..clear()
      ..addAll(snapshot.answers);
    _reactions
      ..clear()
      ..addAll(snapshot.reactions);
    _currentUser =
        snapshot.role == ForumRole.teacher ? _testTeacher : _testStudent;
    _sortPosts();
  }

  /// Enregistre l'état sur l'appareil ; les écritures sont chaînées pour
  /// conserver l'ordre et une erreur de stockage ne bloque jamais l'interface.
  void _persist() {
    final snapshot = _snapshot();
    _saveChain = _saveChain.then((_) => _store.save(snapshot)).catchError(
      (Object error) {
        debugPrint('Forum : enregistrement local impossible ($error)');
      },
    );
  }

  void _commit() {
    _persist();
    _notify();
  }

  void _sortPosts() {
    _posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  String _newId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  // ============================================================ Synchro REST

  /// Vrai si la synchronisation REST est activée (`--dart-define=FORUM_REMOTE=true`).
  bool get remoteEnabled => _api != null;

  /// Dernier message d'erreur de synchronisation (null si tout va bien).
  String? get lastSyncError => _lastSyncError;

  /// Envoie une modification au serveur sans bloquer l'interface. En cas d'échec,
  /// la modification reste enregistrée localement et l'erreur est mémorisée.
  void _syncRemote(Future<void> Function(ForumApiClient api) action) {
    final api = _api;
    if (api == null) return;
    unawaited(() async {
      try {
        await action(api);
        if (_lastSyncError != null) {
          _lastSyncError = null;
          _notify();
        }
      } on ForumApiException catch (error) {
        _lastSyncError = error.message;
        _notify();
      } catch (error) {
        _lastSyncError = 'Synchronisation impossible ($error).';
        _notify();
      }
    }());
  }

  /// Rafraîchit le fil. Sans serveur : simple rechargement visuel. Avec serveur :
  /// fusionne les données distantes (mise à jour ou ajout par identifiant, sans
  /// jamais supprimer une donnée locale).
  Future<void> refresh() async {
    final api = _api;
    if (api == null) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      _notify();
      return;
    }
    try {
      final remote = await api.fetchSnapshot();
      _mergeRemote(remote);
      _lastSyncError = null;
      _persist();
    } on ForumApiException catch (error) {
      _lastSyncError = error.message;
    } catch (error) {
      _lastSyncError = 'Données du serveur invalides ($error).';
    }
    _notify();
  }

  void _mergeRemote(ForumSnapshot remote) {
    for (final post in remote.posts) {
      final index = _posts.indexWhere((p) => p.id == post.id);
      if (index == -1) {
        _posts.add(post);
      } else {
        _posts[index] = post;
      }
    }
    for (final answer in remote.answers) {
      final index = _answers.indexWhere((a) => a.id == answer.id);
      if (index == -1) {
        _answers.add(answer);
      } else {
        _answers[index] = answer;
      }
    }
    for (final reaction in remote.reactions) {
      final index = _reactions.indexWhere((r) => r.id == reaction.id);
      if (index == -1) {
        _reactions.add(reaction);
      } else {
        _reactions[index] = reaction;
      }
    }
    _sortPosts();
  }

  // ================================================================== Getters

  /// Liste des intitulés de cours proposés dans les filtres et le formulaire de création.
  List<String> get courses => MockForumData.coursesList;

  /// Requête de recherche textuelle active.
  String get searchQuery => _searchQuery;

  /// Filtre de cours actif (`allCourses` par défaut).
  String get selectedCourse => _selectedCourse;

  /// Filtre d'état actif (toutes, sans réponse, résolues).
  ForumStatusFilter get statusFilter => _statusFilter;

  /// Tag actif dans le filtre (null si aucun).
  String? get tagFilter => _tagFilter;

  /// Profil utilisateur actif dans la session du forum.
  ForumUser get currentUser => _currentUser;

  /// Indique si le profil courant dispose des privilèges enseignant.
  bool get isTeacher => _currentUser.isTeacher;

  /// Indique si au moins un critère de filtrage est appliqué.
  bool get hasActiveFilters =>
      _searchQuery.trim().isNotEmpty ||
      _selectedCourse != allCourses ||
      _statusFilter != ForumStatusFilter.all ||
      _tagFilter != null;

  /// Tags les plus utilisés (pour les suggestions du formulaire).
  List<String> get popularTags {
    final counts = <String, int>{};
    for (final post in _posts) {
      for (final tag in post.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return entries.map((e) => e.key).toList();
  }

  // ====================================================================== Rôle

  /// Bascule entre le profil étudiant et le profil enseignant puis rafraîchit l'interface.
  void setRole(ForumRole role) {
    if (role == _currentUser.role) return;
    _currentUser = role == ForumRole.teacher ? _testTeacher : _testStudent;
    _commit();
  }

  // ==================================================================== Filtres

  /// Met à jour le mot-clé de recherche et reconstruit la liste filtrée dans `ForumFeedScreen`.
  void setSearchQuery(String query) {
    _searchQuery = query;
    _visibleCount = pageSize;
    _notify();
  }

  /// Applique le filtre sur le cours sélectionné et notifie les widgets observateurs.
  void setSelectedCourse(String course) {
    _selectedCourse = course;
    _visibleCount = pageSize;
    _notify();
  }

  /// Filtre sur l'état des questions (toutes, sans réponse, résolues).
  void setStatusFilter(ForumStatusFilter filter) {
    _statusFilter = filter;
    _visibleCount = pageSize;
    _notify();
  }

  /// Filtre sur un tag (null pour retirer le filtre).
  void setTagFilter(String? tag) {
    _tagFilter = tag;
    _visibleCount = pageSize;
    _notify();
  }

  /// Réinitialise la recherche, le cours, l'état et le tag.
  void resetFilters() {
    _searchQuery = '';
    _selectedCourse = allCourses;
    _statusFilter = ForumStatusFilter.all;
    _tagFilter = null;
    _visibleCount = pageSize;
    _notify();
  }

  // ===================================================================== Questions

  /// Questions correspondant à tous les filtres actifs (cours, tag, état, mot-clé).
  List<Post> get filteredPosts {
    final query = _searchQuery.trim().toLowerCase();
    return _posts.where((post) {
      if (_selectedCourse != allCourses && post.courseName != _selectedCourse) {
        return false;
      }
      if (_tagFilter != null && !post.tags.contains(_tagFilter)) return false;
      if (_statusFilter == ForumStatusFilter.unanswered &&
          post.answersCount > 0) {
        return false;
      }
      if (_statusFilter == ForumStatusFilter.resolved && !post.isResolved) {
        return false;
      }
      if (query.isNotEmpty) {
        final matches = post.title.toLowerCase().contains(query) ||
            post.body.toLowerCase().contains(query) ||
            post.authorName.toLowerCase().contains(query) ||
            post.tags.any((tag) => tag.contains(query));
        if (!matches) return false;
      }
      return true;
    }).toList();
  }

  /// Première page de [filteredPosts] ; [loadMore] en ajoute une suivante.
  List<Post> get visiblePosts {
    final all = filteredPosts;
    return all.length <= _visibleCount ? all : all.sublist(0, _visibleCount);
  }

  /// Vrai s'il reste des questions à afficher après [visiblePosts].
  bool get hasMore => filteredPosts.length > _visibleCount;

  /// Affiche une page supplémentaire de questions (pagination du fil).
  void loadMore() {
    _visibleCount += pageSize;
    _notify();
  }

  /// Recherche une question par son identifiant dans la liste complète, indépendamment des filtres actifs.
  Post? getPostById(String id) {
    final index = _posts.indexWhere((p) => p.id == id);
    return index == -1 ? null : _posts[index];
  }

  /// Extrait les questions posées par des étudiants qui n'ont encore reçu ni réponse
  /// d'un enseignant ni réponse marquée comme vérifiée (alimente `TeacherInboxScreen`).
  List<Post> get pendingPosts {
    return _posts.where((post) {
      if (post.isTeacher) return false;
      final answers = _answers.where((a) => a.postId == post.id);
      return !answers.any((a) => a.isTeacher || a.isTeacherVerified);
    }).toList();
  }

  /// Seul l'auteur peut modifier ou supprimer sa question.
  bool canModifyPost(Post post) =>
      post.authorId.isNotEmpty && post.authorId == _currentUser.id;

  List<String> _cleanTags(List<String> tags) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in tags) {
      final tag = raw.trim().toLowerCase();
      if (tag.isNotEmpty && seen.add(tag)) result.add(tag);
    }
    return result.take(kMaxTags).toList();
  }

  ({String? code, String? language}) _cleanCode(String? code, String? language) {
    final trimmed = code?.trimRight();
    if (trimmed == null || trimmed.trim().isEmpty) {
      return (code: null, language: null);
    }
    return (code: trimmed, language: language ?? 'text');
  }

  /// Crée une question (`POST /posts`) au nom de `_currentUser` et retourne son
  /// identifiant pour la redirection vers `QuestionDetailScreen`.
  String createPost({
    required String title,
    required String body,
    required String courseName,
    List<String> tags = const [],
    String? codeSnippet,
    String? codeLanguage,
  }) {
    final code = _cleanCode(codeSnippet, codeLanguage);
    final post = Post(
      id: _newId('post'),
      authorId: _currentUser.id,
      authorName: _currentUser.name,
      authorRole: _currentUser.roleString,
      courseName: courseName,
      title: title.trim(),
      body: body.trim(),
      tags: _cleanTags(tags),
      codeSnippet: code.code,
      codeLanguage: code.language,
      createdAt: DateTime.now(),
    );

    _posts.insert(0, post);
    _commit();
    _syncRemote((api) => api.createPost(post));
    return post.id;
  }

  /// Modifie une question (`PATCH /posts/:id`). Réservé à son auteur.
  bool updatePost(
    String postId, {
    required String title,
    required String body,
    required String courseName,
    List<String> tags = const [],
    String? codeSnippet,
    String? codeLanguage,
  }) {
    final post = getPostById(postId);
    if (post == null || !canModifyPost(post)) return false;

    final code = _cleanCode(codeSnippet, codeLanguage);
    post
      ..title = title.trim()
      ..body = body.trim()
      ..courseName = courseName
      ..tags = _cleanTags(tags)
      ..codeSnippet = code.code
      ..codeLanguage = code.language
      ..updatedAt = DateTime.now();

    _commit();
    _syncRemote((api) => api.updatePost(post));
    return true;
  }

  /// Supprime une question avec ses réponses et ses réactions (`DELETE /posts/:id`).
  /// Réservé à son auteur.
  bool deletePost(String postId) {
    final post = getPostById(postId);
    if (post == null || !canModifyPost(post)) return false;

    final replyIds =
        _answers.where((a) => a.postId == postId).map((a) => a.id).toSet();
    _answers.removeWhere((a) => a.postId == postId);
    _reactions.removeWhere((r) =>
        (r.targetType == ReactionTarget.post && r.targetId == postId) ||
        (r.targetType == ReactionTarget.reply && replyIds.contains(r.targetId)));
    _posts.removeWhere((p) => p.id == postId);

    _commit();
    _syncRemote((api) => api.deletePost(postId));
    return true;
  }

  // ===================================================================== Réponses

  /// Retrouve une réponse par son identifiant.
  Answer? getAnswerById(String id) {
    final index = _answers.indexWhere((a) => a.id == id);
    return index == -1 ? null : _answers[index];
  }

  /// Récupère les réponses rattachées à [postId] : la réponse acceptée d'abord,
  /// puis les réponses vérifiées par un enseignant, puis les autres.
  List<Answer> getAnswersForPost(String postId) {
    final all = _answers.where((a) => a.postId == postId).toList();
    final acceptedId = getPostById(postId)?.acceptedReplyId;
    return [
      ...all.where((a) => a.id == acceptedId),
      ...all.where((a) => a.id != acceptedId && a.isTeacherVerified),
      ...all.where((a) => a.id != acceptedId && !a.isTeacherVerified),
    ];
  }

  /// Seul l'auteur peut modifier ou supprimer sa réponse.
  bool canModifyAnswer(Answer answer) =>
      answer.authorId.isNotEmpty && answer.authorId == _currentUser.id;

  /// Enregistre une réponse (`POST /replies`), incrémente `answersCount` de la
  /// question et retourne l'identifiant créé (null si le texte est vide ou la question inconnue).
  String? addAnswer({
    required String postId,
    required String body,
    String? codeSnippet,
    String? codeLanguage,
  }) {
    final text = body.trim();
    final post = getPostById(postId);
    if (text.isEmpty || post == null) return null;

    final code = _cleanCode(codeSnippet, codeLanguage);
    final answer = Answer(
      id: _newId('ans'),
      postId: postId,
      authorId: _currentUser.id,
      authorName: _currentUser.name,
      authorRole: _currentUser.roleString,
      body: text,
      codeSnippet: code.code,
      codeLanguage: code.language,
      createdAt: DateTime.now(),
    );

    _answers.add(answer);
    post.answersCount++;

    _commit();
    _syncRemote((api) => api.createReply(answer));
    return answer.id;
  }

  /// Modifie une réponse (`PATCH /replies/:id`). Réservé à son auteur.
  bool updateAnswer(
    String answerId, {
    required String body,
    String? codeSnippet,
    String? codeLanguage,
  }) {
    final answer = getAnswerById(answerId);
    final text = body.trim();
    if (answer == null || text.isEmpty || !canModifyAnswer(answer)) return false;

    final code = _cleanCode(codeSnippet, codeLanguage);
    answer
      ..body = text
      ..codeSnippet = code.code
      ..codeLanguage = code.language
      ..updatedAt = DateTime.now();

    _commit();
    _syncRemote((api) => api.updateReply(answer));
    return true;
  }

  /// Supprime une réponse (`DELETE /replies/:id`) ; si elle était acceptée, la
  /// question redevient ouverte. Réservé à son auteur.
  bool deleteAnswer(String answerId) {
    final answer = getAnswerById(answerId);
    if (answer == null || !canModifyAnswer(answer)) return false;

    final post = getPostById(answer.postId);
    if (post != null) {
      if (post.answersCount > 0) post.answersCount--;
      if (post.acceptedReplyId == answerId) {
        post.acceptedReplyId = null;
        post.status = PostStatus.open;
      }
    }
    _answers.removeWhere((a) => a.id == answerId);
    _reactions.removeWhere(
        (r) => r.targetType == ReactionTarget.reply && r.targetId == answerId);

    _commit();
    _syncRemote((api) => api.deleteReply(answerId));
    return true;
  }

  /// Seul l'auteur de la question peut accepter une réponse.
  bool canAcceptAnswer(Post post) =>
      post.authorId.isNotEmpty && post.authorId == _currentUser.id;

  /// Accepte une réponse (la question devient « résolue ») ou retire l'acceptation
  /// si elle l'était déjà (`PATCH /posts/:id/accept/:replyId`).
  bool toggleAcceptAnswer(String postId, String answerId) {
    final post = getPostById(postId);
    final answer = getAnswerById(answerId);
    if (post == null || answer == null || answer.postId != postId) return false;
    if (!canAcceptAnswer(post)) return false;

    final wasAccepted = post.acceptedReplyId == answerId;
    if (wasAccepted) {
      post.acceptedReplyId = null;
      post.status = PostStatus.open;
    } else {
      post.acceptedReplyId = answerId;
      post.status = PostStatus.resolved;
    }

    _commit();
    _syncRemote((api) => wasAccepted
        ? api.clearAcceptedReply(postId)
        : api.acceptReply(postId, answerId));
    return true;
  }

  /// Marque ou démarque une réponse comme pédagogiquement vérifiée
  /// (`PATCH /replies/:id/verify`). Action protégée par le contrôle de rôle enseignant.
  void toggleVerifyAnswer(String answerId) {
    if (!_currentUser.isTeacher) return;
    final answer = getAnswerById(answerId);
    if (answer == null) return;

    answer.isTeacherVerified = !answer.isTeacherVerified;
    answer.verifiedAt = answer.isTeacherVerified ? DateTime.now() : null;

    _commit();
    _syncRemote(
        (api) => api.verifyReply(answerId, verified: answer.isTeacherVerified));
  }

  // ==================================================================== Réactions

  Iterable<Reaction> _reactionsOf(ReactionTarget target, String targetId) =>
      _reactions.where((r) => r.targetType == target && r.targetId == targetId);

  /// Nombre de réactions sur une cible (éventuellement d'un seul type).
  int reactionCount(ReactionTarget target, String targetId, {ReactionType? type}) {
    return _reactionsOf(target, targetId)
        .where((r) => type == null || r.type == type)
        .length;
  }

  /// Réaction de l'utilisateur courant sur une cible (null s'il n'a pas réagi).
  ReactionType? myReaction(ReactionTarget target, String targetId) {
    for (final reaction in _reactionsOf(target, targetId)) {
      if (reaction.userId == _currentUser.id) return reaction.type;
    }
    return null;
  }

  /// Ajoute, change ou retire la réaction de l'utilisateur courant
  /// (`PUT /reactions` / `DELETE /reactions`). Une seule réaction par utilisateur et par cible :
  /// choisir le même type la retire, choisir un autre type la remplace.
  void toggleReaction(ReactionTarget target, String targetId, ReactionType type) {
    final userId = _currentUser.id;
    final index = _reactions.indexWhere((r) =>
        r.targetType == target && r.targetId == targetId && r.userId == userId);

    if (index != -1 && _reactions[index].type == type) {
      final removed = _reactions.removeAt(index);
      _commit();
      _syncRemote((api) => api.deleteReaction(removed));
      return;
    }

    final reaction = Reaction(
      targetType: target,
      targetId: targetId,
      userId: userId,
      type: type,
    );
    if (index == -1) {
      _reactions.add(reaction);
    } else {
      _reactions[index] = reaction;
    }
    _commit();
    _syncRemote((api) => api.putReaction(reaction));
  }

  // ================================================================ Exécution de code

  /// Exécute un extrait de code via l'API Judge0 (HTTP). Lève une
  /// [CodeRunException] avec un message lisible en cas d'échec.
  Future<CodeRunResult> runCode({
    required String? language,
    required String source,
    String stdin = '',
  }) async {
    final target = CodeRunnerService.languageByKey(language);
    if (target == null) {
      throw const CodeRunException('Langage inconnu.');
    }
    return codeRunner.run(language: target, source: source, stdin: stdin);
  }
}
