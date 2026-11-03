import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/forum_provider.dart';
import '../routes/app_routes.dart';
import '../utils/content_filter.dart';
import '../utils/tag_utils.dart';
import '../widgets/code_editor.dart';
import '../widgets/forum_ui.dart';

/// Formulaire de création d'une question, ou de modification si [postId] est fourni.
class AskQuestionScreen extends StatefulWidget {
  /// Identifiant de la question à modifier (null = nouvelle question).
  final String? postId;

  /// Cours à présélectionner pour une nouvelle question (ex. depuis un cours).
  final String? initialCourse;

  const AskQuestionScreen({super.key, this.postId, this.initialCourse});

  @override
  State<AskQuestionScreen> createState() => _AskQuestionScreenState();
}

class _AskQuestionScreenState extends State<AskQuestionScreen> {
  static const int _titleMin = 5;
  static const int _titleMax = 120;
  static const int _bodyMin = 10;
  static const int _bodyMax = 2000;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  late String _selectedCourse;
  String _codeLanguage = 'python';
  bool _withCode = false;

  bool get _isEditing => widget.postId != null;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ForumProvider>();
    final courses =
        provider.courses.where((c) => c != ForumProvider.allCourses).toList();

    // Pré-sélectionne le cours demandé (fiche d'un cours), sinon le cours filtré
    // dans le fil, sinon le premier de la liste.
    final requested = widget.initialCourse;
    if (requested != null && requested.isNotEmpty && !courses.contains(requested)) {
      courses.insert(0, requested);
    }
    _selectedCourse = (requested != null && courses.contains(requested))
        ? requested
        : courses.contains(provider.selectedCourse)
            ? provider.selectedCourse
            : courses.first;

    // Mode modification : préremplit les champs avec la question existante.
    final existing =
        _isEditing ? provider.getPostById(widget.postId!) : null;
    if (existing != null) {
      _titleController.text = existing.title;
      _bodyController.text = existing.body;
      _tagsController.text = existing.tags.join(', ');
      if (courses.contains(existing.courseName)) {
        _selectedCourse = existing.courseName;
      }
      if (existing.hasCode) {
        _withCode = true;
        _codeController.text = existing.codeSnippet!;
        _codeLanguage = existing.codeLanguage ?? 'python';
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagsController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String? _validateTitle(String? val) {
    final text = val?.trim() ?? '';
    if (text.isEmpty) return 'Veuillez saisir un titre';
    if (text.length < _titleMin) {
      return 'Le titre doit contenir au moins $_titleMin caractères';
    }
    return ContentFilter.validate(text);
  }

  String? _validateBody(String? val) {
    final text = val?.trim() ?? '';
    if (text.isEmpty) return 'Veuillez décrire votre question';
    if (text.length < _bodyMin) {
      return 'La description doit contenir au moins $_bodyMin caractères';
    }
    return ContentFilter.validate(text);
  }

  String? _validateTags(String? val) => validateTags(val ?? '');

  /// Ajoute un tag suggéré au champ, sans doublon et dans la limite autorisée.
  void _addSuggestedTag(String tag) {
    final tags = parseTags(_tagsController.text);
    if (tags.contains(tag) || tags.length >= kMaxTags) return;
    setState(() => _tagsController.text = [...tags, tag].join(', '));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ForumProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final tags = parseTags(_tagsController.text);
    final code = _withCode ? _codeController.text : null;
    final language = _withCode ? _codeLanguage : null;

    if (_isEditing) {
      final ok = provider.updatePost(
        widget.postId!,
        title: _titleController.text,
        body: _bodyController.text,
        courseName: _selectedCourse,
        tags: tags,
        codeSnippet: code,
        codeLanguage: language,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Votre question a été modifiée !'
              : 'Modification impossible : vous n\'êtes pas l\'auteur.'),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
      return;
    }

    final postId = provider.createPost(
      title: _titleController.text,
      body: _bodyController.text,
      courseName: _selectedCourse,
      tags: tags,
      codeSnippet: code,
      codeLanguage: language,
    );

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Votre question a été publiée !'),
        duration: Duration(seconds: 2),
      ),
    );

    // Ouvre directement la question publiée (remplace l'écran de saisie).
    Navigator.pushReplacementNamed(
      context,
      ForumRoutes.forumQuestion,
      arguments: postId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ForumProvider>();
    final courses = provider.courses
        .where((c) => c != ForumProvider.allCourses)
        .toList();
    // Le cours choisi doit toujours figurer dans la liste du menu déroulant.
    if (!courses.contains(_selectedCourse)) courses.insert(0, _selectedCourse);
    final suggestions = provider.popularTags.take(8).toList();

    return Scaffold(
      backgroundColor: ForumColors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close_rounded, color: ForumColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: ForumPageTitle(
          _isEditing ? 'Modifier la question' : 'Poser une question',
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Décrivez votre problème pour obtenir une réponse rapide '
              'des étudiants et des enseignants du cours.',
              style: TextStyle(
                fontSize: 13.5,
                color: ForumColors.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _selectedCourse,
              isExpanded: true,
              decoration: forumInputDecoration(
                label: 'Cours concerné',
                icon: Icons.menu_book_rounded,
              ),
              items: courses.map((course) {
                return DropdownMenuItem<String>(
                  value: course,
                  child: Text(
                    course,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: ForumColors.textSecondary,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedCourse = val);
                }
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _titleController,
              maxLength: _titleMax,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              validator: _validateTitle,
              decoration: forumInputDecoration(
                label: 'Titre',
                hint: 'ex: Comment organiser les providers ?',
                icon: Icons.title_rounded,
              ),
            ),

            const SizedBox(height: 8),

            TextFormField(
              controller: _bodyController,
              maxLines: 6,
              maxLength: _bodyMax,
              textCapitalization: TextCapitalization.sentences,
              validator: _validateBody,
              decoration: forumInputDecoration(
                label: 'Votre question',
                hint: 'Détaillez votre question ou problème...',
              ).copyWith(alignLabelWithHint: true),
            ),

            const SizedBox(height: 8),

            TextFormField(
              controller: _tagsController,
              textInputAction: TextInputAction.done,
              validator: _validateTags,
              decoration: forumInputDecoration(
                label: 'Tags (optionnel)',
                hint: 'flutter, provider, état',
                icon: Icons.sell_outlined,
              ),
            ),

            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: suggestions
                    .map((tag) =>
                        ForumTag(label: tag, onTap: () => _addSuggestedTag(tag)))
                    .toList(),
              ),
            ],

            const SizedBox(height: 8),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: ForumColors.primary,
              title: const Text(
                'Ajouter un extrait de code',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ForumColors.text,
                ),
              ),
              subtitle: const Text(
                'Les lecteurs pourront l\'exécuter depuis la question.',
                style: TextStyle(fontSize: 12.5, color: ForumColors.muted),
              ),
              value: _withCode,
              onChanged: (value) => setState(() => _withCode = value),
            ),

            if (_withCode) ...[
              const SizedBox(height: 8),
              ForumCodeEditor(
                controller: _codeController,
                language: _codeLanguage,
                onLanguageChanged: (value) =>
                    setState(() => _codeLanguage = value),
              ),
            ],

            const SizedBox(height: 16),

            ForumPrimaryCta(
              label: _isEditing
                  ? 'Enregistrer les modifications'
                  : 'Publier ma question',
              icon: _isEditing ? Icons.save_rounded : Icons.send_rounded,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
