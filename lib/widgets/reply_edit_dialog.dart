import 'package:flutter/material.dart';
import '../features/forum/models/answer.dart';
import '../utils/content_filter.dart';
import 'code_editor.dart';
import '../features/forum/widgets/forum_ui.dart';

/// Résultat de la boîte de modification d'une réponse.
class ReplyEditResult {
  final String body;
  final String? codeSnippet;
  final String? codeLanguage;

  const ReplyEditResult({
    required this.body,
    this.codeSnippet,
    this.codeLanguage,
  });
}

/// Ouvre la boîte de modification d'une réponse ; renvoie null si l'utilisateur annule.
Future<ReplyEditResult?> showReplyEditDialog(
  BuildContext context, {
  required Answer answer,
}) {
  return showDialog<ReplyEditResult>(
    context: context,
    builder: (_) => _ReplyEditDialog(answer: answer),
  );
}

class _ReplyEditDialog extends StatefulWidget {
  final Answer answer;

  const _ReplyEditDialog({required this.answer});

  @override
  State<_ReplyEditDialog> createState() => _ReplyEditDialogState();
}

class _ReplyEditDialogState extends State<_ReplyEditDialog> {
  static const int _bodyMin = 3;
  static const int _bodyMax = 1000;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _bodyController;
  late final TextEditingController _codeController;
  late String _language;
  late bool _withCode;

  @override
  void initState() {
    super.initState();
    _bodyController = TextEditingController(text: widget.answer.body);
    _codeController = TextEditingController(text: widget.answer.codeSnippet ?? '');
    _language = widget.answer.codeLanguage ?? 'python';
    _withCode = widget.answer.hasCode;
  }

  @override
  void dispose() {
    _bodyController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String? _validateBody(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Écrivez votre réponse';
    if (text.length < _bodyMin) {
      return 'Votre réponse est trop courte ($_bodyMin caractères minimum)';
    }
    return ContentFilter.validate(text);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final code = _codeController.text;
    Navigator.pop(
      context,
      ReplyEditResult(
        body: _bodyController.text.trim(),
        codeSnippet: _withCode && code.trim().isNotEmpty ? code : null,
        codeLanguage: _withCode ? _language : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Modifier la réponse',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: ForumColors.text,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                TextFormField(
                  controller: _bodyController,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: _bodyMax,
                  textCapitalization: TextCapitalization.sentences,
                  validator: _validateBody,
                  decoration: forumInputDecoration(label: 'Votre réponse')
                      .copyWith(alignLabelWithHint: true),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: ForumColors.primary,
                  title: const Text(
                    'Extrait de code',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: ForumColors.text,
                    ),
                  ),
                  value: _withCode,
                  onChanged: (value) => setState(() => _withCode = value),
                ),
                if (_withCode)
                  ForumCodeEditor(
                    controller: _codeController,
                    language: _language,
                    onLanguageChanged: (value) =>
                        setState(() => _language = value),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(backgroundColor: ForumColors.primary),
          child: const Text(
            'Enregistrer',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
