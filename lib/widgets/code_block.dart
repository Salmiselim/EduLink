import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/forum_provider.dart';
import '../services/code_runner_service.dart';
import '../services/gemini_service.dart';

/// Affiche un extrait de code (fond sombre, police monospace) avec :
/// - un bouton « Copier » ;
/// - un bouton « Exécuter » qui envoie le code à l'API Judge0 (requête HTTP)
///   et affiche la sortie, les erreurs et la durée sous l'extrait ;
/// - un bouton « Expliquer » qui demande à l'API Gemini (clé API) d'expliquer
///   le code, ou l'erreur d'exécution s'il y en a une.
class ForumCodeBlock extends StatefulWidget {
  final String code;
  final String? language;

  const ForumCodeBlock({super.key, required this.code, this.language});

  @override
  State<ForumCodeBlock> createState() => _ForumCodeBlockState();
}

class _ForumCodeBlockState extends State<ForumCodeBlock> {
  static const Color _codeBg = Color(0xFF0F172A);
  static const Color _headerBg = Color(0xFF1E293B);
  static const Color _light = Color(0xFFE2E8F0);
  static const Color _lightMuted = Color(0xFF94A3B8);
  static const Color _errorText = Color(0xFFFCA5A5);
  static const Color _okText = Color(0xFF86EFAC);
  static const Color _aiText = Color(0xFFC4B5FD);

  bool _running = false;
  CodeRunResult? _result;
  String? _error;

  bool _explaining = false;
  String? _explanation;
  String? _aiError;

  Future<void> _run() async {
    final provider = context.read<ForumProvider>();
    setState(() {
      _running = true;
      _result = null;
      _error = null;
      _explanation = null;
      _aiError = null;
    });
    try {
      final result = await provider.runCode(
        language: widget.language,
        source: widget.code,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _running = false;
      });
    } on CodeRunException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _running = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Une erreur inattendue est survenue pendant l'exécution.";
        _running = false;
      });
    }
  }

  /// Erreur de la dernière exécution (compilation, stderr...), null si elle a réussi.
  String? get _errorOutput {
    final result = _result;
    if (result == null || result.success) return null;
    final text = [result.compileOutput, result.stderr, result.message]
        .where((part) => part.trim().isNotEmpty)
        .join('\n');
    return text.isEmpty ? result.statusLabel : text;
  }

  /// Demande à l'assistant IA (Gemini) d'expliquer le code ou l'erreur affichée.
  Future<void> _explain() async {
    final provider = context.read<ForumProvider>();
    setState(() {
      _explaining = true;
      _explanation = null;
      _aiError = null;
    });
    try {
      final text = await provider.explainCode(
        language: widget.language,
        source: widget.code,
        errorOutput: _errorOutput,
      );
      if (!mounted) return;
      setState(() {
        _explanation = text;
        _explaining = false;
      });
    } on AiAssistantException catch (error) {
      if (!mounted) return;
      setState(() {
        _aiError = error.message;
        _explaining = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiError = "Une erreur inattendue est survenue pendant l'analyse.";
        _explaining = false;
      });
    }
  }

  Future<void> _copy() async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: widget.code));
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Code copié dans le presse-papiers'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = CodeRunnerService.languageByKey(widget.language);
    final runnable = language?.runnable ?? false;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: _codeBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête : langage + actions
            Container(
              color: _headerBg,
              padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
              child: Row(
                children: [
                  const Icon(Icons.code_rounded, size: 15, color: _lightMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      language?.label ?? 'Code',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _light,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copier le code',
                    visualDensity: VisualDensity.compact,
                    onPressed: _copy,
                    icon: const Icon(Icons.copy_rounded,
                        size: 16, color: _lightMuted),
                  ),
                  TextButton.icon(
                    onPressed: _explaining ? null : _explain,
                    style: TextButton.styleFrom(
                      foregroundColor: _aiText,
                      disabledForegroundColor: _lightMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: _explaining
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _lightMuted,
                            ),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: Text(
                      _explaining
                          ? 'Analyse...'
                          : (_errorOutput != null
                              ? "Expliquer l'erreur"
                              : 'Expliquer'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (runnable)
                    TextButton.icon(
                      onPressed: _running ? null : _run,
                      style: TextButton.styleFrom(
                        foregroundColor: _okText,
                        disabledForegroundColor: _lightMuted,
                      ),
                      icon: _running
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _lightMuted,
                              ),
                            )
                          : const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(
                        _running ? 'Exécution...' : 'Exécuter',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Code
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                widget.code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  height: 1.45,
                  color: _light,
                ),
              ),
            ),

            // Résultat de l'exécution
            if (_result != null || _error != null) _buildOutput(),

            // Explication de l'assistant IA (Gemini)
            if (_explanation != null || _aiError != null) _buildAiPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildOutput() {
    final result = _result;

    if (_error != null) {
      return _OutputPanel(
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 15, color: _errorText),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 12, color: _errorText),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (result == null) return const SizedBox.shrink();

    final timeLabel = result.time == null ? '' : ' · ${result.time} s';
    return _OutputPanel(
      children: [
        Row(
          children: [
            Icon(
              result.success
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              size: 15,
              color: result.success ? _okText : _errorText,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${result.statusLabel}$timeLabel',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: result.success ? _okText : _errorText,
                ),
              ),
            ),
          ],
        ),
        if (result.stdout.isNotEmpty) _mono(result.stdout, _light),
        if (result.compileOutput.isNotEmpty)
          _mono(result.compileOutput, _errorText),
        if (result.stderr.isNotEmpty) _mono(result.stderr, _errorText),
        if (result.message.isNotEmpty) _mono(result.message, _errorText),
        if (!result.hasOutput) _mono('(aucune sortie)', _lightMuted),
      ],
    );
  }

  Widget _buildAiPanel() {
    final failed = _aiError != null;
    return _OutputPanel(
      children: [
        Row(
          children: [
            Icon(
              failed ? Icons.error_outline_rounded : Icons.auto_awesome_rounded,
              size: 15,
              color: failed ? _errorText : _aiText,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                failed ? _aiError! : 'Explication de l\'assistant IA',
                style: TextStyle(
                  fontSize: failed ? 12 : 11.5,
                  fontWeight: failed ? FontWeight.w400 : FontWeight.w700,
                  color: failed ? _errorText : _aiText,
                ),
              ),
            ),
            InkWell(
              onTap: () => setState(() {
                _explanation = null;
                _aiError = null;
              }),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close_rounded, size: 15, color: _lightMuted),
              ),
            ),
          ],
        ),
        if (!failed) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SelectableText(
              _explanation!,
              style: const TextStyle(fontSize: 12.5, height: 1.45, color: _light),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Généré par IA (Gemini) : à vérifier, ne remplace pas la '
              'réponse validée par un enseignant.',
              style: TextStyle(fontSize: 10.5, color: _lightMuted),
            ),
          ),
        ],
      ],
    );
  }

  Widget _mono(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SelectableText(
        text.trimRight(),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.4,
          color: color,
        ),
      ),
    );
  }
}

class _OutputPanel extends StatelessWidget {
  final List<Widget> children;

  const _OutputPanel({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF020617),
        border: Border(top: BorderSide(color: Color(0xFF334155))),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
