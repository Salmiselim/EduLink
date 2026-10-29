import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/forum_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/forum_ui.dart';

class AskQuestionScreen extends StatefulWidget {
  const AskQuestionScreen({super.key});

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

  late String _selectedCourse;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ForumProvider>();
    final courses =
        provider.courses.where((c) => c != ForumProvider.allCourses).toList();
    // Pré-sélectionne le cours filtré dans le fil, sinon le premier de la liste.
    _selectedCourse = courses.contains(provider.selectedCourse)
        ? provider.selectedCourse
        : courses.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  String? _validateTitle(String? val) {
    final text = val?.trim() ?? '';
    if (text.isEmpty) return 'Veuillez saisir un titre';
    if (text.length < _titleMin) {
      return 'Le titre doit contenir au moins $_titleMin caractères';
    }
    return null;
  }

  String? _validateBody(String? val) {
    final text = val?.trim() ?? '';
    if (text.isEmpty) return 'Veuillez décrire votre question';
    if (text.length < _bodyMin) {
      return 'La description doit contenir au moins $_bodyMin caractères';
    }
    return null;
  }

  void _submitQuestion() {
    if (!_formKey.currentState!.validate()) return;

    final postId = context.read<ForumProvider>().createPost(
          title: _titleController.text,
          body: _bodyController.text,
          courseName: _selectedCourse,
        );

    ScaffoldMessenger.of(context).showSnackBar(
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
        title: const ForumPageTitle('Poser une question'),
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

            const SizedBox(height: 16),

            ForumPrimaryCta(
              label: 'Publier ma question',
              icon: Icons.send_rounded,
              onPressed: _submitQuestion,
            ),
          ],
        ),
      ),
    );
  }
}
