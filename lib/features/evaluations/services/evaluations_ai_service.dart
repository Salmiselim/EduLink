import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/evaluations_models.dart';

// ============================================================================
// SERVICE IA — MODULE ÉVALUATIONS (couche « Service » de l'architecture)
// Génère de vrais brouillons de questions de quiz via l'API Google AI
// (modèle Gemini, plan gratuit d'AI Studio — aucune facturation).
//
// La clé est lue dans le fichier `.env` à la racine du projet
// (GEMINI_API_KEY=...) — la MÊME clé sert au module Cours : une seule
// configuration pour toute l'application.
// Sans clé, sans réseau ou si le service est momentanément surchargé, le
// contrôleur retombe sur son générateur local de démonstration : l'écran
// d'assistant reste utilisable en toutes circonstances (repli gracieux).
// ============================================================================

/// Client IA du module Évaluations : production de questions QCM / Vrai-Faux.
class EvaluationsAiService {
  EvaluationsAiService._();

  /// Instance unique partagée par les écrans du module.
  static final EvaluationsAiService instance = EvaluationsAiService._();

  /// Clé d'API : fichier `.env` (recommandé) ou `--dart-define` (prioritaire).
  static String get _apiKey {
    final fromDefine = const String.fromEnvironment('GEMINI_API_KEY');
    if (fromDefine.isNotEmpty) return fromDefine;
    // Le fichier .env est chargé au démarrage de l'application ; en dehors
    // de ce contexte (tests), l'accès direct lèverait une erreur.
    if (!dotenv.isInitialized) return '';
    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }

  /// Modèles Gemini en CASCADE — chaque modèle a son propre quota gratuit
  /// quotidien (20 requêtes/jour/modèle) : en cas d'épuisement (HTTP 429)
  /// sur l'un, le suivant est essayé automatiquement.
  static const List<String> _models = [
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
  ];

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  /// Vrai si une clé d'API est configurée (sinon : repli local de démo).
  bool get isConfigured => _apiKey.isNotEmpty;

  /// Génère [count] questions de quiz (QCM / Vrai-Faux) à partir d'un
  /// intitulé de chapitre. Retourne `null` en cas d'échec — l'appelant
  /// utilise alors son brouillon local.
  ///
  /// Le modèle est invité à répondre UNIQUEMENT par un tableau JSON ; la
  /// réponse est validée entrée par entrée (type, options, indices de
  /// bonnes réponses dans les bornes, points entre 0.5 et 20) et les
  /// entrées invalides sont ignorées.
  Future<List<QuizQuestion>?> generateQuizQuestions({
    required String topic,
    int count = 3,
  }) async {
    if (!isConfigured) return null;
    final safeCount = count.clamp(1, 10);
    final hint = topic.trim().isEmpty ? 'le chapitre du cours' : topic.trim();
    try {
      final response = await _post(_prompt(hint, safeCount));
      final parsed = _parseQuestions(response, safeCount);
      return parsed.isEmpty ? null : parsed;
    } catch (error) {
      debugPrint('[EvalAi] Échec de génération : $error');
      return null;
    }
  }

  String _prompt(String hint, int count) {
    return "Tu prépares un quiz universitaire en français à partir d'un "
        'intitulé de chapitre.\n'
        'Chapitre : « $hint »\n'
        "Génère $count questions mêlant QCM et Vrai/Faux, de difficulté "
        'progressive.\n'
        'Réponds UNIQUEMENT par un tableau JSON valide, sans texte autour, '
        'au format exact suivant :\n'
        '[{"type":"qcm","text":"énoncé","options":["a","b","c","d"],'
        '"correct":[0],"points":2.5,"explanation":"pourquoi"},'
        '{"type":"vrai_faux","text":"affirmation","options":["Vrai","Faux"],'
        '"correct":[1],"points":1,"explanation":"pourquoi"}]\n'
        'Contraintes : 4 options pour un qcm, 2 pour un vrai_faux ; '
        '"correct" contient les INDICES (à partir de 0) des bonnes réponses ; '
        'points entre 0.5 et 20 ; explication pédagogique d\'une phrase.';
  }

  Future<String> _post(String prompt, {int modelIndex = 0, int attempt = 0}) async {
    if (modelIndex >= _models.length) {
      // Tous les modèles ont épuisé leur quota : l'appelant retombe sur son
      // générateur local.
      throw StateError('Tous les modèles Gemini sont indisponibles.');
    }
    final model = _models[modelIndex];
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '$model:generateContent',
        queryParameters: {'key': _apiKey},
        data: {
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': const {'temperature': 0.5},
        },
      );
      final candidates = response.data?['candidates'] as List<dynamic>?;
      final first = candidates != null && candidates.isNotEmpty
          ? candidates.first as Map<String, dynamic>?
          : null;
      final content = first?['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      return (parts ?? [])
          .whereType<Map<String, dynamic>>()
          .map((part) => part['text'])
          .whereType<String>()
          .join();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 503 && attempt == 0) {
        // Pointe de charge passagère : un court réessai sur le même modèle.
        await Future<void>.delayed(const Duration(seconds: 3));
        return _post(prompt, modelIndex: modelIndex, attempt: attempt + 1);
      }
      if (status == 429) {
        // Quota journalier du modèle épuisé : modèle suivant.
        return _post(prompt, modelIndex: modelIndex + 1);
      }
      rethrow;
    }
  }

  /// Analyse la réponse : extraction du tableau JSON, nettoyage des clôtures
  /// Markdown éventuelles, validation champ par champ.
  List<QuizQuestion> _parseQuestions(String raw, int maxCount) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text
          .replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '')
          .replaceFirst(RegExp(r'```\s*$'), '')
          .trim();
    }
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start < 0 || end <= start) return [];
    List<dynamic> decoded;
    try {
      decoded = jsonDecode(text.substring(start, end + 1)) as List<dynamic>;
    } catch (_) {
      return [];
    }
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final questions = <QuizQuestion>[];
    for (var i = 0; i < decoded.length && questions.length < maxCount; i++) {
      final entry = decoded[i];
      if (entry is! Map<String, dynamic>) continue;
      final typeRaw = (entry['type'] as String?) ?? 'qcm';
      final type = typeRaw == 'vrai_faux'
          ? QuestionType.vraiFaux
          : QuestionType.qcm;
      final text = (entry['text'] as String?)?.trim() ?? '';
      final options =
          ((entry['options'] as List?) ?? const []).cast<String>();
      final correct = ((entry['correct'] as List?) ?? const [])
          .whereType<num>()
          .map((n) => n.toInt())
          .where((idx) => idx >= 0 && idx < options.length)
          .toList();
      final points = (entry['points'] as num?)?.toDouble() ?? 1.0;
      final explanation = (entry['explanation'] as String?) ?? '';
      if (text.length < 5) continue;
      if (options.isEmpty || options.any((o) => o.trim().isEmpty)) continue;
      if (correct.isEmpty) continue;
      if (points < 0.5 || points > 20) continue;
      questions.add(
        QuizQuestion(
          id: 'gen_${stamp}_${questions.length}',
          type: type,
          text: text,
          options: options,
          correct: correct,
          points: points,
          explanation: explanation,
        ),
      );
    }
    return questions;
  }
}
