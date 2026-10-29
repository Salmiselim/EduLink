import 'dart:async';
import 'package:flutter/material.dart';
import '../data/evaluations_mock_data.dart';
import '../models/evaluations_models.dart';
import '../routes/evaluations_routes.dart';
import '../widgets/eval_ui.dart';

class QuizTakeScreen extends StatefulWidget {
  final String quizId;
  const QuizTakeScreen({super.key, required this.quizId});

  @override
  State<QuizTakeScreen> createState() => _QuizTakeScreenState();
}

class _QuizTakeScreenState extends State<QuizTakeScreen> {
  final _controller = EvaluationsController.instance;
  late final Quiz _quiz;
  late final String _attemptId;
  late List<List<int>> _answers;
  late int _remainingSeconds;
  Timer? _timer;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _quiz = _controller.quizById(widget.quizId)!;
    _attemptId = _controller.startAttempt(widget.quizId);
    _answers = List.generate(_quiz.questions.length, (_) => <int>[]);
    _remainingSeconds = _quiz.timeLimitMin * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        _submit(auto: true);
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle(int qi, int oi) {
    final q = _quiz.questions[qi];
    setState(() {
      final current = [..._answers[qi]];
      if (q.type == QuestionType.vraiFaux || !q.isMultiple) {
        _answers[qi] = [oi];
      } else if (current.contains(oi)) {
        current.remove(oi);
        _answers[qi] = current;
      } else {
        current.add(oi);
        _answers[qi] = current;
      }
    });
    _controller.saveAttemptAnswers(_attemptId, _answers);
  }

  Future<void> _submit({bool auto = false}) async {
    if (_submitting) return;
    if (!auto) {
      for (var i = 0; i < _answers.length; i++) {
        if (_answers[i].isEmpty) {
          setState(
            () => _error = 'Répondez à toutes les questions avant de soumettre.',
          );
          return;
        }
      }
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    _timer?.cancel();
    _controller.saveAttemptAnswers(_attemptId, _answers);
    final score = _controller.submitAttempt(_attemptId);
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      EvaluationsRoutes.quizResults,
      arguments: QuizResultsArgs(quizId: _quiz.id, attemptId: _attemptId),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          auto
              ? 'Temps écoulé — quiz soumis automatiquement. Note : ${EvaluationsController.formatScore(score)} / 20'
              : 'Correction automatique : ${EvaluationsController.formatScore(score)} / 20',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = 1 - (_remainingSeconds / (_quiz.timeLimitMin * 60));
    final mm = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_remainingSeconds % 60).toString().padLeft(2, '0');
    final urgent = _remainingSeconds < 60;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Quitter le quiz ?'),
            content: const Text(
              'Le chronomètre continue côté serveur mock. Soumettez plutôt vos réponses.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Rester'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Quitter'),
              ),
            ],
          ),
        );
        if (leave == true && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: EduColors.scaffold,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _quiz.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: EduColors.text,
                ),
              ),
              Text(
                '${_quiz.courseTitle} · ${_mmDisplay(mm, ss)}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: urgent ? EduColors.danger : EduColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            LinearProgressIndicator(
              value: progress.clamp(0, 1),
              color: urgent ? EduColors.danger : EduColors.primary,
              backgroundColor: EduColors.border,
              minHeight: 6,
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _quiz.questions.length,
                itemBuilder: (context, i) => _questionCard(i),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: EduColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: PrimaryCta(
                label: 'Soumettre le quiz',
                icon: Icons.task_alt_rounded,
                onPressed: _submitting ? null : () => _submit(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _mmDisplay(String mm, String ss) => '$mm:$ss restantes';

  Widget _questionCard(int i) {
    final q = _quiz.questions[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: evalCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusChip(
            label: 'Question ${i + 1} · ${q.points.toStringAsFixed(0)} pts',
            color: EduColors.primary,
          ),
          const SizedBox(height: 8),
          Text(
            q.text,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: EduColors.text,
            ),
          ),
          if (q.isMultiple)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Plusieurs réponses possibles',
                style: TextStyle(fontSize: 12, color: EduColors.muted),
              ),
            ),
          const SizedBox(height: 8),
          ...List.generate(q.options.length, (oi) {
            final selected = _answers[i].contains(oi);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilterChip(
                  selected: selected,
                  label: Text(q.options[oi]),
                  onSelected: (_) => _toggle(i, oi),
                  selectedColor: EduColors.infoBg,
                  checkmarkColor: EduColors.primary,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
