import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Service IA du module Cours (couche « Service » de l'architecture) :
// dialogue avec l'API Google AI (Gemini) pour assister l'enseignant et
// l'étudiant. La clé est fournie au lancement via --dart-define=GEMINI_API_KEY=...
// Sans clé ou sans réseau, chaque méthode lève [AiUnavailableException] et
// l'interface conserve son comportement habituel (repli gracieux, comme le
// mode démonstration du reste de l'application).

/// Langues cibles proposées pour la traduction des contenus de cours.
class CourseLanguage {
  /// Code de langue stocké dans les documents Firestore (`en`, `ar`, `es`).
  final String code;

  /// Libellé lisible affiché dans les sélecteurs de langue.
  final String label;

  /// Vrai pour les langues s'écrivant de droite à gauche (arabe) : les écrans
  /// adaptent la direction du texte affiché.
  final bool rtl;

  const CourseLanguage(this.code, this.label, {this.rtl = false});

  /// Langues de traduction disponibles dans le module Cours.
  static const List<CourseLanguage> available = [
    CourseLanguage('en', 'Anglais'),
    CourseLanguage('ar', 'Arabe', rtl: true),
    CourseLanguage('es', 'Espagnol'),
  ];

  /// Retrouve une langue par son code, ou `null` si inconnue.
  static CourseLanguage? byCode(String code) {
    for (final language in available) {
      if (language.code == code) return language;
    }
    return null;
  }
}

/// Exception levée lorsque le service IA ne peut pas répondre (clé absente,
/// réseau indisponible, erreur de l'API). Le message est affiché tel quel
/// à l'utilisateur via un `SnackBar`.
class AiUnavailableException implements Exception {
  final String message;
  const AiUnavailableException(this.message);

  @override
  String toString() => message;
}

/// Client unique du module Cours vers l'API Google AI (modèle Gemini).
/// Toutes les méthodes construisent une consigne en français et retournent
/// le texte brut produit par le modèle.
class CoursesAiService {
  CoursesAiService._();

  /// Instance unique partagée par tous les écrans du module.
  static final CoursesAiService instance = CoursesAiService._();

  /// Clé d'API : lue dans le fichier `.env` au démarrage de l'application
  /// (méthode recommandée — voir `.env` à la racine du projet), ou injectée
  /// à la compilation via `--dart-define` (prioritaire si elle est fournie).
  /// Vide en tests et chez les membres qui n'ont pas configuré leur clé : le
  /// service est alors « non configuré » et l'UI affiche un message d'aide.
  static String get _apiKey {
    final fromDefine = const String.fromEnvironment('GEMINI_API_KEY');
    if (fromDefine.isNotEmpty) return fromDefine;
    // Le fichier .env est chargé au démarrage de l'application ; en dehors
    // de ce contexte (tests), l'accès direct lèverait une erreur.
    if (!dotenv.isInitialized) return '';
    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }

  /// Modèles Gemini en CASCADE — chaque modèle dispose de son propre quota
  /// gratuit quotidien (20 requêtes/jour/modèle sur AI Studio) : quand le
  /// premier est épuisé (HTTP 429), on passe automatiquement au suivant.
  /// `gemini-2.5-flash` n'est plus attribué aux nouveaux comptes.
  static const List<String> _models = [
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
  ];

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  /// Vrai si une clé d'API a été fournie au lancement de l'application.
  bool get isConfigured => _apiKey.isNotEmpty;

  /// Message affiché dans les `SnackBar` quand la clé n'est pas configurée.
  static const String notConfiguredMessage =
      "IA non configurée : collez votre clé Gemini dans le fichier .env "
      'du projet (aistudio.google.com), puis relancez l\'application.';

  /// Envoie une consigne au modèle et retourne le texte de la réponse.
  /// Stratégie en cascade : en cas de quota journalier épuisé (HTTP 429)
  /// sur un modèle, le suivant est essayé automatiquement ; une pointe de
  /// charge (HTTP 503) déclenche un court réessai sur le même modèle avant
  /// de passer au suivant. Si tous les modèles sont épuisés, une
  /// [AiUnavailableException] avec le message adapté est levée.
  Future<String> _generate(String prompt) async {
    if (!isConfigured) {
      throw const AiUnavailableException(notConfiguredMessage);
    }
    var quotaHit = false;
    Object? lastError;
    for (final model in _models) {
      try {
        final response = await _postWithRetry(model, prompt);
        return _extractText(response);
      } on DioException catch (error) {
        lastError = error;
        if (error.response?.statusCode == 429) quotaHit = true;
        // Quota du modèle épuisé ou erreur isolée : modèle suivant.
      } on AiUnavailableException {
        // Réponse vide sur ce modèle : essayer le suivant.
        continue;
      }
    }
    debugPrint('[CoursesAi] Échec sur tous les modèles : $lastError');
    if (quotaHit) {
      throw const AiUnavailableException(
        'Quota gratuit journalier épuisé — réessaie demain matin '
        '(réinitialisation vers 8h).',
      );
    }
    throw const AiUnavailableException(
      'Service IA momentanément indisponible — vérifiez la connexion.',
    );
  }

  /// Un essai sur un modèle, avec un unique réessai rapide en cas de forte
  /// demande (503). Un 429 n'est PAS retenté sur le même modèle (quota du
  /// jour épuisé) : il remonte pour déclencher la cascade.
  Future<Response<Map<String, dynamic>>> _postWithRetry(
    String model,
    String prompt,
  ) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _send(model, prompt);
      } on DioException catch (error) {
        if (error.response?.statusCode == 503 && attempt == 0) {
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
        rethrow;
      }
    }
    throw const AiUnavailableException(
      'Service IA momentanément indisponible.',
    );
  }

  Future<Response<Map<String, dynamic>>> _send(String model, String prompt) {
    return _dio.post<Map<String, dynamic>>(
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
        'generationConfig': const {'temperature': 0.4},
      },
    );
  }

  /// Extrait le texte de la réponse de l'API (liste de parties du candidat).
  String _extractText(Response<Map<String, dynamic>> response) {
    final data = response.data;
    final candidates = data?['candidates'] as List<dynamic>?;
    final first = candidates != null && candidates.isNotEmpty
        ? candidates.first as Map<String, dynamic>?
        : null;
    final content = first?['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    final text = (parts ?? [])
        .whereType<Map<String, dynamic>>()
        .map((part) => part['text'])
        .whereType<String>()
        .join();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const AiUnavailableException(
        "L'IA n'a renvoyé aucune réponse. Réessayez dans un instant.",
      );
    }
    return trimmed;
  }

  /// Suggère une description de cours à partir des informations de l'étape 1.
  Future<String> suggestDescription({
    required String title,
    required String subject,
    required String level,
  }) {
    return _generate(
      'Tu aides un enseignant universitaire à rédiger la présentation d\'un '
      'cours sur une application de scolarité étudiante.\n'
      'Titre du cours : « $title »\n'
      'Matière : $subject\n'
      'Niveau : $level\n'
      'Rédige une description de 3 à 4 phrases en français : contenu couvert, '
      'ce que l\'étudiant saura faire à la fin, ton clair et motivant. '
      'Ne renvoie QUE le texte de la description, sans titre, sans guillemets, '
      'sans liste ni mise en forme.',
    );
  }

  /// Propose un plan de cours : une liste de titres de chapitres.
  Future<List<String>> proposeOutline({
    required String title,
    required String subject,
    required String level,
    int count = 5,
  }) async {
    final raw = await _generate(
      'Tu aides un enseignant universitaire à structurer un cours.\n'
      'Titre du cours : « $title »\n'
      'Matière : $subject\n'
      'Niveau : $level\n'
      'Propose $count titres de chapitres qui suivent une progression '
      'pédagogique logique, du plus simple au plus avancé.\n'
      'Réponds uniquement avec $count lignes, une par chapitre, sans '
      'numérotation, sans tiret ni puce, sans texte d\'introduction.',
    );
    return raw
        .split('\n')
        .map((line) => line.trim())
        .map((line) => line.replaceFirst(RegExp(r'^[-•*]\s*'), ''))
        .map((line) => line.replaceFirst(RegExp(r'^\d+[.)]\s*'), ''))
        .where((line) => line.isNotEmpty)
        .take(12)
        .toList();
  }

  /// Rédige un brouillon de contenu pour un chapitre de type « texte ».
  Future<String> draftChapterContent({
    required String courseTitle,
    required String subject,
    required String chapterTitle,
  }) {
    return _generate(
      'Tu rédiges le contenu pédagogique d\'un chapitre de cours universitaire '
      'en français, pour des étudiants de niveau licence.\n'
      'Cours : « $courseTitle » (matière : $subject)\n'
      'Chapitre à rédiger : « $chapterTitle »\n'
      'Rédige 3 à 5 paragraphes pédagogiques clairs (définitions, explications, '
      'un exemple concret). Sépare les paragraphes par une ligne vide. '
      'Ne renvoie QUE le contenu du chapitre, sans titre ni conclusion formatée.',
    );
  }

  /// Relit un cours (titre, matière, niveau, description) et retourne une
  /// relecture : correction de l'orthographe + conseils de clarté.
  Future<String> reviewCourse({
    required String title,
    required String subject,
    required String level,
    required String description,
  }) {
    return _generate(
      'Tu relis la présentation d\'un cours universitaire avant publication '
      'sur une application de scolarité.\n'
      'Titre : « $title »\n'
      'Matière : $subject\n'
      'Niveau : $level\n'
      'Description : « $description »\n'
      'Réponds en français avec exactement ces 3 sections courtes :\n'
      'Orthographe : liste les fautes d\'orthographe ou de grammaire trouvées '
      '(avec la correction), ou écris « Rien à signaler ».\n'
      'Clarté : 2 conseils concrets pour améliorer la description.\n'
      'Attractivité : 1 phrase pour dire si le cours donne envie de s\'inscrire '
      'et pourquoi.',
    );
  }

  /// Vérifie l'orthographe d'un champ de formulaire et retourne UNIQUEMENT le
  /// texte corrigé (identique à l'original si rien à corriger).
  Future<String> correctSpelling({
    required String label,
    required String text,
  }) {
    return _generate(
      'Corrige uniquement l\'orthographe, la grammaire et les accents du '
      'texte français suivant (champ « $label » d\'un formulaire de cours '
      'universitaire). Conserve le style, les majuscules et la longueur : '
      'n\'ajoute rien, ne réécris pas, ne reformule pas.\n'
      'Texte :\n"""\n$text\n"""\n'
      'Ne renvoie QUE le texte corrigé, sans explication ni guillemets. '
      'S\'il n\'y a aucune faute, renvoie le texte à l\'identique.',
    );
  }

  /// Résume un chapitre en 3 points clés pour l'étudiant.
  Future<String> summarizeChapter({
    required String courseTitle,
    required String chapterTitle,
    required String content,
  }) {
    return _generate(
      'Tu aides un étudiant à réviser. Résume en français le chapitre suivant '
      'en exactement 3 points clés, chacun sur une ligne commençant par « • ».\n'
      'Cours : « $courseTitle »\n'
      'Chapitre : « $chapterTitle »\n'
      'Contenu :\n"""\n$content\n"""\n'
      'Ne renvoie QUE les 3 lignes de résumé.',
    );
  }

  /// Traduit un texte pédagogique vers la langue cible et retourne
  /// uniquement la traduction.
  Future<String> translateText({
    required String text,
    required CourseLanguage language,
    String? context,
  }) {
    final contextLine = context == null ? '' : 'Contexte : $context.\n';
    return _generate(
      'Tu traduis un contenu pédagogique universitaire du français vers '
      '${language.label}. $contextLine'
      'Traduis fidèlement, avec un registre clair et pédagogique.\n'
      'Texte :\n"""\n$text\n"""\n'
      'Ne renvoie QUE la traduction, sans explication ni guillemets.',
    );
  }

  /// Traduit la description ET tous les chapitres texte d'un cours en
  /// UNE SEULE requête par langue (économie de quota : pour un cours de
  /// 6 chapitres et 2 langues, 2 appels au lieu de 14 — chaque modèle
  /// gratuit n'acceptant que 20 requêtes par jour).
  ///
  /// Retourne une map dont la clé `"description"` est la traduction de la
  /// description et les autres clés sont les identifiants de chapitres
  /// transmis dans [items] avec leur traduction. Retourne `null` si la
  /// réponse est inexploitable (l'appelant garde ses textes originaux).
  Future<Map<String, String>?> translateCourseBundle({
    required String description,
    required Map<String, String> items,
    required CourseLanguage language,
    required String courseTitle,
  }) async {
    if (items.isEmpty && description.trim().isEmpty) return null;
    final buffer = StringBuffer();
    for (final entry in items.entries) {
      buffer
        ..writeln('[BLOC ${entry.key}]')
        ..writeln('"""')
        ..writeln(entry.value)
        ..writeln('"""');
    }
    final response = await _generate(
      "Tu traduis l'intégralité d'un cours universitaire du français vers "
      '${language.label}.\n'
      'Cours : « $courseTitle ».\n'
      'Traduis fidèlement chaque bloc, avec un registre clair et '
      'pédagogique, sans rien ajouter ni omettre.\n'
      'Réponds UNIQUEMENT par un objet JSON valide, sans texte autour, '
      'au format exact suivant :\n'
      '{"description":"<traduction de la description>",'
      '"blocs":{"<identifiant du bloc>":"<traduction>"}}\n'
      'La description à traduire :\n"""\n$description\n"""\n\n'
      'Les blocs identifiés à traduire :\n'
      '${buffer.toString()}',
    );

    // Extraction du JSON (tolère une clôture Markdown éventuelle).
    var text = response.trim();
    if (text.startsWith('```')) {
      text = text
          .replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '')
          .replaceFirst(RegExp(r'```\s*$'), '')
          .trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded =
          jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
      final result = <String, String>{};
      final translatedDescription = (decoded['description'] as String?) ?? '';
      if (translatedDescription.trim().isNotEmpty) {
        result['description'] = translatedDescription.trim();
      }
      final blocs = (decoded['blocs'] as Map?) ?? const {};
      blocs.forEach((key, value) {
        final translated = (value as String?)?.trim() ?? '';
        if (translated.isNotEmpty && items.containsKey(key.toString())) {
          result[key.toString()] = translated;
        }
      });
      if (result.isEmpty) return null;
      return result;
    } on FormatException {
      return null;
    } catch (error) {
      debugPrint('[CoursesAi] Bundle illisible : $error');
      return null;
    }
  }

  /// Décode proprement une réponse JSON éventuellement encadrée de balises
  /// Markdown (utilitaire réservé aux évolutions futures du service).
  Map<String, dynamic>? tryDecodeJson(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text
          .replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '')
          .replaceFirst(RegExp(r'```\s*$'), '')
          .trim();
    }
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
