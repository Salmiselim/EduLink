import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/mock_forum_data.dart';
import '../features/courses/data/courses_mock_data.dart';
import '../features/forum/models/answer.dart';
import '../features/forum/models/post.dart';
import '../models/rating.dart';
import '../models/reaction.dart';
import '../features/forum/models/user.dart';
import '../services/code_runner_service.dart';
import '../services/forum_firebase_link.dart';
import '../services/forum_remote.dart';
import '../services/forum_store.dart';
import '../services/gemini_service.dart';
import '../services/stack_overflow_service.dart';
import '../utils/rating_utils.dart';
import '../utils/tag_utils.dart';

/// Filtre sur l'état des questions dans le fil.
enum ForumStatusFilter { all, unanswered, resolved }

/// Ordre d'affichage du fil : date, note moyenne ou popularité.
enum ForumSortOrder { recent, topRated, popular }

/// Gestionnaire d'état central du Forum basé sur `ChangeNotifier`.
///
/// Source de vérité en mémoire des questions (`Post`), réponses (`Answer`) et
/// réactions (`Reaction`). Chaque modification est :
/// 1. appliquée en mémoire puis notifiée aux écrans (`notifyListeners`) ;
/// 2. enregistrée sur l'appareil via [ForumStore] (SharedPreferences) ;
/// 3. envoyée à Cloud Firestore via [ForumRemote] quand un compte Firebase est
///    connecté : les données du serveur remplacent alors les données locales
///    et se mettent à jour en temps réel (cache hors-ligne du SDK).
class ForumProvider with ChangeNotifier {
  /// Libellé représentant l'absence de filtre sur un cours particulier.
  static const String allCourses = 'Tous les cours';

  /// Cours proposé par défaut quand aucun cours n'est disponible.
  static const String generalCourse = 'Général';

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
  final bool _linkFirebase;

  /// Service d'exécution de code (Judge0), utilisé par `ForumCodeBlock`.
  final CodeRunnerService codeRunner;

  /// API Stack Exchange : questions similaires sur Stack Overflow (formulaire de question).
  final StackOverflowService stackOverflow;

  /// API Gemini : explication d'un code ou d'une erreur (`ForumCodeBlock`).
  final GeminiService codeAssistant;

  final List<Post> _posts = [];
  final List<Answer> _answers = [];
  final List<Reaction> _reactions = [];
  final List<Rating> _ratings = [];

  String _searchQuery = '';
  String _selectedCourse = allCourses;
  ForumStatusFilter _statusFilter = ForumStatusFilter.all;
  ForumSortOrder _sortOrder = ForumSortOrder.recent;
  String? _tagFilter;
  int _visibleCount = pageSize;

  ForumUser _currentUser = _testStudent;
  int _idCounter = 0;
  bool _isReady = false;
  bool _disposed = false;
  String? _lastSyncError;
  final StreamController<String> _syncErrorController =
      StreamController<String>.broadcast();
  Future<void> _saveChain = Future<void>.value();

  // Mode connecté (Cloud Firestore)
  ForumRemote? _remote;
  ForumFirebaseLink? _firebaseLink;
  final List<StreamSubscription<dynamic>> _remoteSubs = [];
  ForumSnapshot? _localBackup;
  bool _postsLoaded = false;
  bool _repliesLoaded = false;

  ForumProvider({
    ForumStore? store,
    CodeRunnerService? codeRunner,
    StackOverflowService? stackOverflow,
    GeminiService? codeAssistant,
    bool linkFirebase = true,
  })  : _store = store ?? SharedPrefsForumStore(),
        _linkFirebase = linkFirebase,
        codeRunner = codeRunner ?? CodeRunnerService(),
        stackOverflow = stackOverflow ?? StackOverflowService(),
        codeAssistant = codeAssistant ?? GeminiService() {
    _posts.addAll(MockForumData.getInitialPosts());
    _answers.addAll(MockForumData.getInitialAnswers());
    _reactions.addAll(MockForumData.getInitialReactions());
    _ratings.addAll(MockForumData.getInitialRatings());
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
    // Relie le Forum au compte Firebase (sans effet si Firebase n'est pas configuré).
    if (_linkFirebase && _firebaseLink == null) {
      _firebaseLink = ForumFirebaseLink.start(this);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _firebaseLink?.dispose();
    for (final sub in _remoteSubs) {
      sub.cancel();
    }
    _remoteSubs.clear();
    _remote?.close();
    _syncErrorController.close();
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
        ratings: List<Rating>.of(_ratings),
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
    _ratings
      ..clear()
      ..addAll(snapshot.ratings);
    _currentUser =
        snapshot.role == ForumRole.teacher ? _testTeacher : _testStudent;
    _sortPosts();
  }

  /// Enregistre l'état sur l'appareil ; les écritures sont chaînées pour
  /// conserver l'ordre et une erreur de stockage ne bloque jamais l'interface.
  void _persist() {
    // Connecté, Firestore (et son cache hors-ligne) fait foi : on ne mélange pas
    // ses données avec la copie locale du mode démonstration.
    if (_remote != null) return;
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

  // ======================================================== Cloud Firestore

  /// Vrai quand le Forum est branché sur Firestore avec un compte connecté.
  bool get isOnline => _remote != null;

  /// Dernier message d'erreur de synchronisation (null si tout va bien).
  String? get lastSyncError => _lastSyncError;

  /// Émet un message à chaque modification refusée par le serveur (les écrans
  /// l'affichent dans une barre d'information).
  Stream<String> get syncErrors => _syncErrorController.stream;

  /// Branche le Forum sur la base distante avec l'identité de [user].
  /// Les données locales (mode démonstration) sont mises de côté puis
  /// restaurées par [disconnectRemote]. Les listes se remplissent ensuite
  /// avec les flux temps réel (écritures en attente hors-ligne comprises).
  void connectRemote(ForumRemote remote, {required ForumUser user}) {
    if (_remote != null) _detachRemote(restoreLocal: false);

    _localBackup ??= _snapshot();
    _remote = remote;
    _currentUser = user;
    _posts.clear();
    _answers.clear();
    _reactions.clear();
    _ratings.clear();
    _postsLoaded = false;
    _repliesLoaded = false;
    _lastSyncError = null;
    _visibleCount = pageSize;

    _remoteSubs
      ..add(remote.watchPosts().listen(_onRemotePosts, onError: _onRemoteError))
      ..add(remote.watchReplies().listen(_onRemoteReplies, onError: _onRemoteError))
      ..add(remote
          .watchReactions()
          .listen(_onRemoteReactions, onError: _onRemoteError))
      ..add(remote
          .watchRatings()
          .listen(_onRemoteRatings, onError: _onRemoteError));
    _notify();
  }

  /// Met à jour le profil connecté (nom, rôle) sans recharger les données.
  void updateRemoteUser(ForumUser user) {
    if (_remote == null) return;
    _currentUser = user;
    _notify();
  }

  /// Quitte le mode connecté et restaure les données locales.
  void disconnectRemote() {
    if (_remote == null) return;
    _detachRemote(restoreLocal: true);
    _notify();
  }

  void _detachRemote({required bool restoreLocal}) {
    for (final sub in _remoteSubs) {
      sub.cancel();
    }
    _remoteSubs.clear();
    _remote?.close();
    _remote = null;
    _lastSyncError = null;
    if (restoreLocal) {
      final backup = _localBackup;
      _localBackup = null;
      if (backup != null) _applySnapshot(backup);
    }
  }

  void _onRemotePosts(List<Post> posts) {
    _posts
      ..clear()
      ..addAll(posts);
    _sortPosts();
    _postsLoaded = true;
    _reconcile();
    _notify();
  }

  void _onRemoteReplies(List<Answer> replies) {
    _answers
      ..clear()
      ..addAll(replies);
    _repliesLoaded = true;
    _reconcile();
    _notify();
  }

  void _onRemoteReactions(List<Reaction> reactions) {
    _reactions
      ..clear()
      ..addAll(reactions);
    _notify();
  }

  void _onRemoteRatings(List<Rating> ratings) {
    _ratings
      ..clear()
      ..addAll(ratings);
    _notify();
  }

  void _onRemoteError(Object error) {
    _lastSyncError = error is ForumRemoteException
        ? error.message
        : 'Lecture du forum impossible ($error).';
    _notify();
  }

  /// Recalcule les champs dérivés après un changement distant : nombre de
  /// réponses (les règles réservent la modification d'une question à son
  /// auteur, ce compteur ne peut donc pas être tenu à jour par les autres) et
  /// réponse acceptée qui n'existe plus.
  void _reconcile() {
    if (!_postsLoaded || !_repliesLoaded) return;
    final counts = <String, int>{};
    final replyIds = <String>{};
    for (final answer in _answers) {
      counts[answer.postId] = (counts[answer.postId] ?? 0) + 1;
      replyIds.add(answer.id);
    }
    for (final post in _posts) {
      post.answersCount = counts[post.id] ?? 0;
      final accepted = post.acceptedReplyId;
      if (accepted != null && !replyIds.contains(accepted)) {
        post.acceptedReplyId = null;
        post.status = PostStatus.open;
      }
    }
  }

  /// Envoie une modification au serveur sans bloquer l'interface. En cas
  /// d'échec (règles de sécurité, réseau), l'erreur est mémorisée ; le flux
  /// temps réel rétablit alors l'état réel du serveur.
  void _syncRemote(Future<void> Function(ForumRemote remote) action) {
    final remote = _remote;
    if (remote == null) return;
    unawaited(() async {
      try {
        await action(remote);
        if (identical(remote, _remote) && _lastSyncError != null) {
          _lastSyncError = null;
          _notify();
        }
      } on ForumRemoteException catch (error) {
        _reportSyncError(remote, error.message);
      } catch (error) {
        _reportSyncError(remote, 'Synchronisation impossible ($error).');
      }
    }());
  }

  void _reportSyncError(ForumRemote remote, String message) {
    if (!identical(remote, _remote)) return;
    _lastSyncError = message;
    if (!_syncErrorController.isClosed) _syncErrorController.add(message);
    _notify();
  }

  /// Tirer pour actualiser : les flux temps réel sont déjà à jour, l'appel
  /// relance simplement l'affichage.
  Future<void> refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _notify();
  }

  // ================================================================== Getters

  /// Intitulés de cours proposés dans les filtres et le formulaire de création :
  /// les cours publiés du module Cours, ceux déjà utilisés par des questions et
  /// « Général ». Hors connexion, la liste d'exemple du Forum est conservée.
  List<String> get courses {
    final names = <String>{};
    if (_remote == null) {
      names.addAll(MockForumData.coursesList.where((c) => c != allCourses));
    }
    for (final course in CoursesController.instance.publishedCourses) {
      names.add(course.title);
    }
    for (final post in _posts) {
      if (post.courseName.isNotEmpty) names.add(post.courseName);
    }
    names.add(generalCourse);
    return [allCourses, ...names];
  }

  /// Requête de recherche textuelle active.
  String get searchQuery => _searchQuery;

  /// Filtre de cours actif (`allCourses` par défaut).
  String get selectedCourse => _selectedCourse;

  /// Filtre d'état actif (toutes, sans réponse, résolues).
  ForumStatusFilter get statusFilter => _statusFilter;

  /// Tag actif dans le filtre (null si aucun).
  String? get tagFilter => _tagFilter;

  /// Ordre d'affichage du fil (récentes par défaut).
  ForumSortOrder get sortOrder => _sortOrder;

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
    // Connecté, le rôle vient du compte Firebase (users/{uid}) et ne se change pas ici.
    if (_remote != null) return;
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

  /// Change l'ordre du fil : date, mieux notées ou populaires.
  void setSortOrder(ForumSortOrder order) {
    _sortOrder = order;
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
    final result = _posts.where((post) {
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
    _sortPostsFor(result);
    return result;
  }

  /// Applique l'ordre choisi (la liste reçue est déjà triée par date).
  /// - Mieux notées : score bayésien des étoiles, puis nombre de notes, puis date.
  /// - Populaires : réactions + 2 × notes + réponses, puis date.
  void _sortPostsFor(List<Post> list) {
    if (_sortOrder == ForumSortOrder.recent) return;
    final stats = _ratingIndex();
    final reactionCounts = <String, int>{};
    for (final reaction in _reactions) {
      if (reaction.targetType == ReactionTarget.post) {
        reactionCounts[reaction.targetId] =
            (reactionCounts[reaction.targetId] ?? 0) + 1;
      }
    }
    RatingStats statsOf(Post p) =>
        stats[_targetKey(ReactionTarget.post, p.id)] ?? RatingStats.empty;
    int engagement(Post p) =>
        (reactionCounts[p.id] ?? 0) + statsOf(p).count * 2 + p.answersCount;

    list.sort((a, b) {
      if (_sortOrder == ForumSortOrder.topRated) {
        final sa = statsOf(a);
        final sb = statsOf(b);
        final byScore = sb.score.compareTo(sa.score);
        if (byScore != 0) return byScore;
        final byCount = sb.count.compareTo(sa.count);
        if (byCount != 0) return byCount;
      } else {
        final byEngagement = engagement(b).compareTo(engagement(a));
        if (byEngagement != 0) return byEngagement;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  static String _targetKey(ReactionTarget target, String id) =>
      '${target.name}_$id';

  /// Totaux des notes par cible, calculés en un seul passage.
  Map<String, RatingStats> _ratingIndex() {
    final index = <String, RatingStats>{};
    for (final rating in _ratings) {
      final key = _targetKey(rating.targetType, rating.targetId);
      index[key] = (index[key] ?? RatingStats.empty).add(rating.stars);
    }
    return index;
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
    _syncRemote((remote) => remote.savePost(post));
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
    _syncRemote((remote) => remote.savePost(post));
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
    _ratings.removeWhere((r) =>
        (r.targetType == ReactionTarget.post && r.targetId == postId) ||
        (r.targetType == ReactionTarget.reply && replyIds.contains(r.targetId)));
    _posts.removeWhere((p) => p.id == postId);

    _commit();
    _syncRemote((remote) => remote.deletePost(postId));
    return true;
  }

  // ===================================================================== Réponses

  /// Retrouve une réponse par son identifiant.
  Answer? getAnswerById(String id) {
    final index = _answers.indexWhere((a) => a.id == id);
    return index == -1 ? null : _answers[index];
  }

  /// Récupère les réponses rattachées à [postId] : la réponse acceptée d'abord,
  /// puis les réponses vérifiées par un enseignant, puis les autres. Dans chaque
  /// groupe, les mieux notées remontent (score bayésien), puis les plus anciennes.
  List<Answer> getAnswersForPost(String postId) {
    final all = _answers.where((a) => a.postId == postId).toList();
    final stats = _ratingIndex();
    double scoreOf(Answer a) =>
        (stats[_targetKey(ReactionTarget.reply, a.id)] ?? RatingStats.empty)
            .score;
    all.sort((a, b) {
      final byScore = scoreOf(b).compareTo(scoreOf(a));
      return byScore != 0 ? byScore : a.createdAt.compareTo(b.createdAt);
    });
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
  String?   addAnswer({
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
    _syncRemote((remote) => remote.saveReply(answer));
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
    _syncRemote((remote) => remote.saveReply(answer));
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
    _ratings.removeWhere(
        (r) => r.targetType == ReactionTarget.reply && r.targetId == answerId);

    _commit();
    _syncRemote((remote) => remote.deleteReply(answerId));
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
    _syncRemote((remote) => remote.setAcceptedReply(
          postId,
          replyId: wasAccepted ? null : answerId,
        ));
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
    _syncRemote((remote) => remote.setReplyVerified(
          answerId,
          verified: answer.isTeacherVerified,
          at: answer.verifiedAt,
        ));
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
      _syncRemote((remote) => remote.deleteReaction(removed));
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
    _syncRemote((remote) => remote.saveReaction(reaction, replacing: index != -1));
  }

  // ======================================================================= Notes

  /// Nombre et somme des notes reçues par une question ou une réponse
  /// (`stats.average` = moyenne affichée, `stats.score` = score de classement).
  RatingStats ratingStats(ReactionTarget target, String targetId) {
    var stats = RatingStats.empty;
    for (final rating in _ratings) {
      if (rating.targetType == target && rating.targetId == targetId) {
        stats = stats.add(rating.stars);
      }
    }
    return stats;
  }

  /// Note de l'utilisateur courant sur une cible (null s'il n'a pas noté).
  int? myRating(ReactionTarget target, String targetId) {
    for (final rating in _ratings) {
      if (rating.targetType == target &&
          rating.targetId == targetId &&
          rating.userId == _currentUser.id) {
        return rating.stars;
      }
    }
    return null;
  }

  /// On ne note ni son propre contenu ni un contenu qui n'existe plus.
  bool canRate(ReactionTarget target, String targetId) {
    final authorId = target == ReactionTarget.post
        ? getPostById(targetId)?.authorId
        : getAnswerById(targetId)?.authorId;
    return authorId != null && authorId != _currentUser.id;
  }

  /// Donne [stars] (1 à 5) à une cible ; renvoyer la même note la retire.
  /// Une seule note par utilisateur et par cible (`PUT` / `DELETE` sur `ratings`).
  /// Renvoie false si la note est refusée (hors 1-5, contenu personnel).
  bool rate(ReactionTarget target, String targetId, int stars) {
    if (stars < Rating.minStars || stars > Rating.maxStars) return false;
    if (!canRate(target, targetId)) return false;

    final userId = _currentUser.id;
    final index = _ratings.indexWhere((r) =>
        r.targetType == target && r.targetId == targetId && r.userId == userId);

    if (index != -1 && _ratings[index].stars == stars) {
      final removed = _ratings.removeAt(index);
      _commit();
      _syncRemote((remote) => remote.deleteRating(removed));
      return true;
    }

    final rating = Rating(
      targetType: target,
      targetId: targetId,
      userId: userId,
      stars: stars,
    );
    if (index == -1) {
      _ratings.add(rating);
    } else {
      _ratings[index] = rating;
    }
    _commit();
    _syncRemote((remote) => remote.saveRating(rating));
    return true;
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

  // ============================================================ API externes (clés)

  /// Questions Stack Overflow proches de [title] (API Stack Exchange, clé
  /// d'application). Lève une [StackOverflowException] avec un message lisible.
  Future<List<StackQuestion>> findSimilarQuestions({
    required String title,
    String? codeLanguage,
  }) {
    return stackOverflow.searchSimilar(
      title: title,
      codeLanguage: codeLanguage,
    );
  }

  /// Explication pédagogique d'un extrait de code (API Gemini, clé API).
  /// [errorOutput] : sortie d'erreur de l'exécution Judge0, si elle existe.
  /// Lève une [AiAssistantException] avec un message lisible.
  Future<String> explainCode({
    required String? language,
    required String source,
    String? errorOutput,
  }) {
    final label = CodeRunnerService.languageByKey(language)?.label ?? language;
    return codeAssistant.explainCode(
      code: source,
      language: label,
      errorOutput: errorOutput,
    );
  }
}
