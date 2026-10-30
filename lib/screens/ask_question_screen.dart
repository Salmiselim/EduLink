import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/forum_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/forum_ui.dart';

/// Écran de saisie permettant de publier une nouvelle question sur le Forum.
/// Accessible depuis le bouton flottant de `ForumFeedScreen` via `ForumRoutes.forumAsk`.
class AskQuestionScreen extends StatefulWidget {
  const AskQuestionScreen({super.key});

  @override
  State<AskQuestionScreen> createState() => _AskQuestionScreenState();
}

class _AskQuestionScreenState extends State<AskQuestionScreen> {
  /// Bornes de longueur appliquées lors de la validation du titre et de la description.
  static const int _titleMin = 5;
  static const int _titleMax = 120;
  static const int _bodyMin = 10;
  static const int _bodyMax = 2000;

  /// Clé globale pilotant la validation simultanée des champs du `Form`.
  final _formKey = GlobalKey<FormState>();

  /// Contrôleurs de saisie pour l'intitulé et le détail de la question.
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  /// Cours rattaché à la question en cours de rédaction.
  late String _selectedCourse;

  @override
  void initState() {
    super.initState();
    // Lecture ponctuelle (`context.read`) du provider pour pré-sélectionner le cours actif du fil.
    final provider = context.read<ForumProvider>();
    final courses =
        provider.courses.where((c) => c != ForumProvider.allCourses).toList();
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

  /// Vérifie que le titre est renseigné et respecte la longueur minimale `_titleMin`.
  String? _validateTitle(String? val) {
    final text = val?.trim() ?? '';
    if (text.isEmpty) return 'Veuillez saisir un titre';
    if (text.length < _titleMin) {
      return 'Le titre doit contenir au moins $_titleMin caractères';
    }
    return null;
  }

  /// Vérifie que le corps de la question est renseigné et atteint au moins `_bodyMin` caractères.
  String? _validateBody(String? val) {
    final text = val?.trim() ?? '';
    if (text.isEmpty) return 'Veuillez décrire votre question';
    if (text.length < _bodyMin) {
      return 'La description doit contenir au moins $_bodyMin caractères';
    }
    return null;
  }

  /// Valide le formulaire, enregistre la question dans `ForumProvider`, affiche un `SnackBar`
  /// puis ouvre son écran de détail en remplaçant la page de création dans la pile.
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

    // Remplace l'écran de rédaction par `QuestionDetailScreen` via la route nommée.
    Navigator.pushReplacementNamed(
      context,
      ForumRoutes.forumQuestion,
      arguments: postId,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Écoute réactive de `ForumProvider` pour disposer de la liste à jour des cours.
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
      // Formulaire validé au fil de la saisie grâce à `AutovalidateMode.onUserInteraction`.
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

            // Liste déroulante de sélection du cours concerné par la question.
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

            // Champ du titre limité à `_titleMax` caractères et validé par `_validateTitle`.
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

            // Champ multiligne de description détaillée validé par `_validateBody`.
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

            // Bouton d'action principal soumettant le formulaire.
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
