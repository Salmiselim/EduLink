import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/evaluations_models.dart';

/// Couche HTTP du module Évaluations.
///
/// Tous les appels REST vers le backend NestJS passent ici.
/// Chaque méthode :
///   - Ajoute automatiquement le token Firebase dans l'en-tête Authorization (L1).
///   - Retourne des objets métier désérialisés prêts à l'emploi.
///   - Lance une [EvalApiException] en cas d'erreur réseau ou serveur.
///
/// L'URL de base est lue depuis la constante [baseUrl] (à remplacer par
/// flutter_dotenv ou une variable d'environnement en production).
class EvaluationsApiService {
  // ── Configuration ────────────────────────────────────────────────────────

  /// URL de base du backend NestJS. À externaliser via .env en production.
  static const String baseUrl = 'http://10.0.2.2:3000'; // AVD → localhost

  /// Instance Dio partagée configurée avec les intercepteurs d'authentification.
  late final Dio _dio;

  /// Callback permettant d'injecter le token Firebase depuis [EvaluationsRepository].
  /// Retourne null si l'utilisateur n'est pas connecté (mock autorisé en debug).
  final Future<String?> Function() _getToken;

  EvaluationsApiService({required Future<String?> Function() getToken})
      : _getToken = getToken {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // Intercepteur : injection du token Firebase à chaque requête (L1 — AuthGuard).
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (DioException e, handler) {
        debugPrint('[EvalAPI] Erreur ${e.response?.statusCode} — ${e.message}');
        handler.next(e);
      },
    ));
  }

  // ── Helpers internes ─────────────────────────────────────────────────────

  /// Exécute [call] en interceptant les [DioException] et les transforme
  /// en [EvalApiException] avec code HTTP et message lisible.
  Future<T> _safe<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      final message = e.response?.data?['message'] as String? ??
          e.message ??
          'Erreur réseau inconnue';
      throw EvalApiException(code: code, message: message);
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // QUIZ
  // ════════════════════════════════════════════════════════════════════════

  /// Récupère tous les quiz accessibles selon le rôle courant.
  /// Enseignant : ses propres quiz.  Étudiant : quiz publiés de ses cours.
  Future<List<Quiz>> getQuizzes({String? courseId}) => _safe(() async {
        final resp = await _dio.get(
          '/quizzes',
          queryParameters: courseId != null ? {'courseId': courseId} : null,
        );
        return (resp.data as List)
            .map((j) => _quizFromJson(j as Map<String, dynamic>))
            .toList();
      });

  /// Récupère un quiz précis par son identifiant.
  Future<Quiz> getQuiz(String quizId) => _safe(() async {
        final resp = await _dio.get('/quizzes/$quizId');
        return _quizFromJson(resp.data as Map<String, dynamic>);
      });

  /// Crée un nouveau quiz (enseignant). Retourne le quiz créé avec son `id`.
  Future<Quiz> createQuiz(Map<String, dynamic> body) => _safe(() async {
        final resp = await _dio.post('/quizzes', data: body);
        return _quizFromJson(resp.data as Map<String, dynamic>);
      });

  /// Met à jour les champs d'un quiz existant (brouillon ou publié).
  Future<Quiz> updateQuiz(String quizId, Map<String, dynamic> body) =>
      _safe(() async {
        final resp = await _dio.patch('/quizzes/$quizId', data: body);
        return _quizFromJson(resp.data as Map<String, dynamic>);
      });

  /// Supprime définitivement un quiz (uniquement si non publié).
  Future<void> deleteQuiz(String quizId) =>
      _safe(() async => _dio.delete('/quizzes/$quizId'));

  /// Publie un quiz : le rend visible aux étudiants inscrits au cours (L4).
  Future<Quiz> publishQuiz(String quizId) => _safe(() async {
        final resp = await _dio.patch('/quizzes/$quizId/publish');
        return _quizFromJson(resp.data as Map<String, dynamic>);
      });

  /// Soumet le texte d'un chapitre à Gemini pour générer un brouillon de quiz.
  /// Retourne une liste de questions suggérées (L'enseignant valide avant publication).
  Future<List<Map<String, dynamic>>> generateQuizDraft({
    required String chapterText,
    required int questionCount,
  }) =>
      _safe(() async {
        final resp = await _dio.post('/quizzes/generate', data: {
          'chapterText': chapterText,
          'questionCount': questionCount,
        });
        return (resp.data['questions'] as List)
            .cast<Map<String, dynamic>>();
      });

  // ── Tentatives (quiz_attempts) ───────────────────────────────────────────

  /// Démarre une nouvelle tentative pour l'étudiant connecté.
  /// Le serveur vérifie la limite `attemptsAllowed` et retourne l'objet tentative.
  Future<QuizAttempt> startAttempt(String quizId) => _safe(() async {
        final resp = await _dio.post('/quizzes/$quizId/attempts');
        return _attemptFromJson(resp.data as Map<String, dynamic>);
      });

  /// Soumet les réponses d'une tentative pour correction automatique côté serveur.
  /// Le serveur calcule le score et déclenche `BadgesService.checkAndGrant` (L2).
  Future<QuizAttempt> submitAttempt(
    String attemptId,
    List<List<int>> answers,
  ) =>
      _safe(() async {
        final resp = await _dio.patch(
          '/attempts/$attemptId/submit',
          data: {'answers': answers},
        );
        return _attemptFromJson(resp.data as Map<String, dynamic>);
      });

  /// Récupère les statistiques agrégées par question pour l'enseignant.
  Future<Map<String, dynamic>> getQuizResults(String quizId) =>
      _safe(() async {
        final resp = await _dio.get('/quizzes/$quizId/results');
        return resp.data as Map<String, dynamic>;
      });

  // ════════════════════════════════════════════════════════════════════════
  // ASSIGNMENTS (dépôts)
  // ════════════════════════════════════════════════════════════════════════

  /// Récupère tous les devoirs selon le rôle courant et optionnellement le cours.
  Future<List<Assignment>> getAssignments({String? courseId}) =>
      _safe(() async {
        final resp = await _dio.get(
          '/assignments',
          queryParameters: courseId != null ? {'courseId': courseId} : null,
        );
        return (resp.data as List)
            .map((j) => _assignmentFromJson(j as Map<String, dynamic>))
            .toList();
      });

  /// Récupère un devoir précis par son identifiant.
  Future<Assignment> getAssignment(String assignmentId) => _safe(() async {
        final resp = await _dio.get('/assignments/$assignmentId');
        return _assignmentFromJson(resp.data as Map<String, dynamic>);
      });

  /// Crée un nouveau devoir (enseignant). FCM notifie les étudiants inscrits (L8).
  Future<Assignment> createAssignment(Map<String, dynamic> body) =>
      _safe(() async {
        final resp = await _dio.post('/assignments', data: body);
        return _assignmentFromJson(resp.data as Map<String, dynamic>);
      });

  /// Met à jour un devoir existant.
  Future<Assignment> updateAssignment(
    String assignmentId,
    Map<String, dynamic> body,
  ) =>
      _safe(() async {
        final resp = await _dio.patch('/assignments/$assignmentId', data: body);
        return _assignmentFromJson(resp.data as Map<String, dynamic>);
      });

  /// Supprime un devoir (uniquement si aucune copie déposée).
  Future<void> deleteAssignment(String assignmentId) =>
      _safe(() async => _dio.delete('/assignments/$assignmentId'));

  // ── Submissions (copies étudiantes) ─────────────────────────────────────

  /// Dépose une copie pour un devoir. `fileUrls` viennent de MediaService (L10).
  /// `isLate` est calculé côté serveur en comparant `now` avec `dueDate`.
  Future<Submission> submitAssignment({
    required String assignmentId,
    required List<String> fileUrls,
    required String comment,
  }) =>
      _safe(() async {
        final resp = await _dio.post(
          '/assignments/$assignmentId/submissions',
          data: {'fileUrls': fileUrls, 'comment': comment},
        );
        return _submissionFromJson(resp.data as Map<String, dynamic>);
      });

  /// Récupère toutes les copies d'un devoir (enseignant).
  Future<List<Submission>> getSubmissions(String assignmentId) =>
      _safe(() async {
        final resp =
            await _dio.get('/assignments/$assignmentId/submissions');
        return (resp.data as List)
            .map((j) => _submissionFromJson(j as Map<String, dynamic>))
            .toList();
      });

  /// Récupère une copie précise (enseignant ou étudiant pour son propre dépôt).
  Future<Submission> getSubmission(String submissionId) => _safe(() async {
        final resp = await _dio.get('/submissions/$submissionId');
        return _submissionFromJson(resp.data as Map<String, dynamic>);
      });

  /// Note une copie : FCM notifie l'étudiant de la publication de sa note (L8).
  /// Déclenche `BadgesService.checkAndGrant` si copies corrigées (L2).
  Future<Submission> gradeSubmission({
    required String submissionId,
    required double grade,
    required String feedback,
  }) =>
      _safe(() async {
        final resp = await _dio.patch(
          '/submissions/$submissionId/grade',
          data: {'grade': grade, 'feedback': feedback},
        );
        return _submissionFromJson(resp.data as Map<String, dynamic>);
      });

  // ════════════════════════════════════════════════════════════════════════
  // DOCUMENTS
  // ════════════════════════════════════════════════════════════════════════

  /// Récupère tous les documents d'un cours.
  /// Enseignant : accède aux non-visibles ; étudiant : filtrés par `visibleFrom`.
  Future<List<CourseDocument>> getDocuments(String courseId) =>
      _safe(() async {
        final resp = await _dio.get('/courses/$courseId/documents');
        return (resp.data as List)
            .map((j) => _documentFromJson(j as Map<String, dynamic>))
            .toList();
      });

  /// Crée un document pédagogique. `fileUrl` vient de MediaService (L10).
  Future<CourseDocument> createDocument(Map<String, dynamic> body) =>
      _safe(() async {
        final resp = await _dio.post('/documents', data: body);
        return _documentFromJson(resp.data as Map<String, dynamic>);
      });

  /// Met à jour les métadonnées d'un document (titre, dossier, ordre, visibilité).
  Future<CourseDocument> updateDocument(
    String documentId,
    Map<String, dynamic> body,
  ) =>
      _safe(() async {
        final resp = await _dio.patch('/documents/$documentId', data: body);
        return _documentFromJson(resp.data as Map<String, dynamic>);
      });

  /// Supprime un document du cours.
  Future<void> deleteDocument(String documentId) =>
      _safe(() async => _dio.delete('/documents/$documentId'));

  // ════════════════════════════════════════════════════════════════════════
  // GRADEBOOK & UPCOMING
  // ════════════════════════════════════════════════════════════════════════

  /// Retourne le carnet de notes consolidé pour un cours (enseignant ou étudiant).
  Future<List<GradebookRow>> getGradebook(String courseId) =>
      _safe(() async {
        final resp = await _dio.get('/courses/$courseId/gradebook');
        return (resp.data as List)
            .map((j) => _gradebookRowFromJson(j as Map<String, dynamic>))
            .toList();
      });

  /// Retourne la liste des évaluations à venir pour l'étudiant connecté.
  Future<List<Map<String, dynamic>>> getUpcoming() => _safe(() async {
        final resp = await _dio.get('/evaluations/upcoming');
        return (resp.data as List).cast<Map<String, dynamic>>();
      });

  // ════════════════════════════════════════════════════════════════════════
  // DÉSÉRIALISATION
  // ════════════════════════════════════════════════════════════════════════

  /// Exposé publiquement pour permettre au [EvaluationsRepository] de
  /// désérialiser les entrées JSON stockées dans le cache Hive local.
  Quiz quizFromJsonPublic(Map<String, dynamic> j) => _quizFromJson(j);

  Quiz _quizFromJson(Map<String, dynamic> j) => Quiz(
        id: j['id'] as String,
        courseId: j['courseId'] as String,
        courseTitle: j['courseTitle'] as String? ?? '',
        teacherId: j['teacherId'] as String,
        teacherName: j['teacherName'] as String? ?? '',
        title: j['title'] as String,
        timeLimitMin: (j['timeLimitMin'] as num).toInt(),
        attemptsAllowed: (j['attemptsAllowed'] as num).toInt(),
        availableFrom: DateTime.parse(j['availableFrom'] as String),
        dueDate: DateTime.parse(j['dueDate'] as String),
        isPublished: j['isPublished'] as bool? ?? false,
        questions: (j['questions'] as List? ?? [])
            .map((q) => _questionFromJson(q as Map<String, dynamic>))
            .toList(),
      );

  QuizQuestion _questionFromJson(Map<String, dynamic> j) => QuizQuestion(
        id: j['id'] as String,
        type: (j['type'] as String) == 'vrai_faux'
            ? QuestionType.vraiFaux
            : QuestionType.qcm,
        text: j['text'] as String,
        options: (j['options'] as List).cast<String>(),
        correct: (j['correct'] as List).cast<int>(),
        points: (j['points'] as num).toDouble(),
        explanation: j['explanation'] as String? ?? '',
      );

  QuizAttempt _attemptFromJson(Map<String, dynamic> j) => QuizAttempt(
        id: j['id'] as String,
        quizId: j['quizId'] as String,
        studentId: j['studentId'] as String,
        studentName: j['studentName'] as String? ?? '',
        attemptNo: (j['attemptNo'] as num).toInt(),
        answers: (j['answers'] as List? ?? [])
            .map((a) => (a as List).cast<int>())
            .toList(),
        score: j['score'] != null ? (j['score'] as num).toDouble() : null,
        startedAt: DateTime.parse(j['startedAt'] as String),
        submittedAt: j['submittedAt'] != null
            ? DateTime.parse(j['submittedAt'] as String)
            : null,
      );

  Assignment _assignmentFromJson(Map<String, dynamic> j) => Assignment(
        id: j['id'] as String,
        courseId: j['courseId'] as String,
        courseTitle: j['courseTitle'] as String? ?? '',
        teacherId: j['teacherId'] as String,
        teacherName: j['teacherName'] as String? ?? '',
        title: j['title'] as String,
        instructions: j['instructions'] as String? ?? '',
        attachments: (j['attachments'] as List? ?? []).cast<String>(),
        dueDate: DateTime.parse(j['dueDate'] as String),
        maxGrade: (j['maxGrade'] as num).toDouble(),
        allowLate: j['allowLate'] as bool? ?? false,
      );

  Submission _submissionFromJson(Map<String, dynamic> j) => Submission(
        id: j['id'] as String,
        assignmentId: j['assignmentId'] as String,
        studentId: j['studentId'] as String,
        studentName: j['studentName'] as String? ?? '',
        fileUrls: (j['fileUrls'] as List? ?? []).cast<String>(),
        comment: j['comment'] as String? ?? '',
        submittedAt: DateTime.parse(j['submittedAt'] as String),
        isLate: j['isLate'] as bool? ?? false,
        status: (j['status'] as String?) == 'graded'
            ? SubmissionStatus.graded
            : SubmissionStatus.submitted,
        grade: j['grade'] != null ? (j['grade'] as num).toDouble() : null,
        feedback: j['feedback'] as String?,
        gradedAt: j['gradedAt'] != null
            ? DateTime.parse(j['gradedAt'] as String)
            : null,
      );

  CourseDocument _documentFromJson(Map<String, dynamic> j) {
    final folderStr = j['folder'] as String? ?? 'polycopies';
    final folder = DocumentFolder.values.firstWhere(
      (f) => f.name == folderStr,
      orElse: () => DocumentFolder.polycopies,
    );
    return CourseDocument(
      id: j['id'] as String,
      courseId: j['courseId'] as String,
      courseTitle: j['courseTitle'] as String? ?? '',
      teacherId: j['teacherId'] as String,
      teacherName: j['teacherName'] as String? ?? '',
      title: j['title'] as String,
      description: j['description'] as String? ?? '',
      folder: folder,
      fileUrl: j['fileUrl'] as String? ?? '',
      order: (j['order'] as num? ?? 0).toInt(),
      visibleFrom: DateTime.parse(j['visibleFrom'] as String),
      downloadsCount: (j['downloadsCount'] as num? ?? 0).toInt(),
    );
  }

  GradebookRow _gradebookRowFromJson(Map<String, dynamic> j) => GradebookRow(
        studentId: j['studentId'] as String,
        studentName: j['studentName'] as String? ?? '',
        courseTitle: j['courseTitle'] as String? ?? '',
        itemType: j['itemType'] as String? ?? '',
        itemTitle: j['itemTitle'] as String? ?? '',
        grade: j['grade'] != null ? (j['grade'] as num).toDouble() : null,
        maxGrade: (j['maxGrade'] as num? ?? 20).toDouble(),
        status: j['status'] as String? ?? 'pending',
        datedAt:
            j['datedAt'] != null ? DateTime.parse(j['datedAt'] as String) : null,
      );
}

// ════════════════════════════════════════════════════════════════════════════
// Exception métier
// ════════════════════════════════════════════════════════════════════════════

/// Exception levée par [EvaluationsApiService] lors d'une erreur HTTP ou réseau.
/// Contient le code de statut HTTP et un message lisible pour affichage dans l'UI.
class EvalApiException implements Exception {
  final int code;
  final String message;
  const EvalApiException({required this.code, required this.message});

  @override
  String toString() => 'EvalApiException($code): $message';
}
