import 'package:flutter/material.dart';
import '../services/code_runner_service.dart';
import '../features/forum/widgets/forum_ui.dart';

/// Saisie d'un extrait de code : choix du langage + champ monospace.
/// Utilisé par le formulaire de question, la barre de réponse et la modification d'une réponse.
class ForumCodeEditor extends StatelessWidget {
  static const int maxLength = 4000;

  final TextEditingController controller;
  final String language;
  final ValueChanged<String> onLanguageChanged;

  const ForumCodeEditor({
    super.key,
    required this.controller,
    required this.language,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(language),
          initialValue: language,
          isExpanded: true,
          decoration: forumInputDecoration(
            label: 'Langage',
            icon: Icons.code_rounded,
          ),
          items: CodeRunnerService.languages.map((lang) {
            return DropdownMenuItem<String>(
              value: lang.key,
              child: Text(
                lang.runnable ? lang.label : '${lang.label} (non exécutable)',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: ForumColors.textSecondary,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) onLanguageChanged(value);
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          minLines: 5,
          maxLines: 12,
          maxLength: maxLength,
          keyboardType: TextInputType.multiline,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.4,
            color: ForumColors.text,
          ),
          decoration: forumInputDecoration(
            label: 'Code',
            hint: 'Collez votre code ici...',
          ).copyWith(alignLabelWithHint: true),
        ),
      ],
    );
  }
}
