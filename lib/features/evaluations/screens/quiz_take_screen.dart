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
    final q = _controller.quizById(widget.quizId);
    if (q == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pop(context));
      return;
    }
    _quiz = q;
    _attemptId = _controller.startAttempt(widget.quizId);
    _answers = List.generate(_quiz.questions.length, (_) => <int>[]);
    _remainingSeconds = _quiz.timeLimitMin * 60;
    _startTimer();
  }

  void _startTimer() {
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

  void _toggleOption(int qi, int oi) {
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
      _error = null;
    });
    _controller.saveAttemptAnswers(_attemptId, _answers);
  }

  int get _answeredCount => _answers.where((a) => a.isNotEmpty).length;

  Future<void> _submit({bool auto = false}) async {
    if (_submitting) return;

    if (!auto && _answeredCount < _quiz.questions.length) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Questions non répondues'),
          content: Text(
            'Vous avez répondu à $_answeredCount sur ${_quiz.questions.length} questions. '
            'Voulez-vous tout de même soumettre votre copie ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuer le quiz'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Soumettre'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
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
        backgroundColor: score >= 10 ? EduColors.success : EduColors.danger,
        content: Text(
          auto
              ? 'Temps écoulé — copie soumise automatiquement. Note : ${EvaluationsController.formatScore(score)} / 20'
              : 'Correction automatique terminée : ${EvaluationsController.formatScore(score)} / 20',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSeconds = _quiz.timeLimitMin * 60;
    final progress = totalSeconds > 0 ? 1 - (_remainingSeconds / totalSeconds) : 0.0;
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
              'Le chronomètre continue de tourner en arrière-plan. '
              'Pour valider votre note, vous devez soumettre vos réponses.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Rester'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: EduColors.danger),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Abandonner'),
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
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _quiz.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: EduColors.text,
                      ),
                    ),
                    Text(
                      '${_quiz.courseTitle} · $_answeredCount/${_quiz.questions.length} répondue(s)',
                      style: const TextStyle(fontSize: 11.5, color: EduColors.muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: urgent ? EduColors.dangerBg : EduColors.infoBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      urgent ? Icons.alarm_on_rounded : Icons.timer_outlined,
                      size: 16,
                      color: urgent ? EduColors.danger : EduColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$mm:$ss',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        fontFamily: 'monospace',
                        color: urgent ? EduColors.danger : EduColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              color: urgent ? EduColors.danger : EduColors.primary,
              backgroundColor: EduColors.border,
              minHeight: 5,
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _quiz.questions.length,
                itemBuilder: (context, i) => _questionCard(i),
              ),
            ),
            if (_error != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: EduColors.dangerBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: EduColors.danger, fontWeight: FontWeight.w600),
                ),
              ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SafeArea(
                top: false,
                child: PrimaryCta(
                  label: _submitting ? 'Correction en cours…' : 'Soumettre le quiz ($_answeredCount/${_quiz.questions.length})',
                  icon: Icons.task_alt_rounded,
                  onPressed: _submitting ? null : () => _submit(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _questionCard(int i) {
    final q = _quiz.questions[i];
    final answered = _answers[i].isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: evalCardDecoration(
        borderColor: answered ? EduColors.primary.withValues(alpha: 0.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(
                label: 'Question ${i + 1} / ${_quiz.questions.length}',
                color: EduColors.primary,
              ),
              const SizedBox(width: 8),
              StatusChip(
                label: '${q.points.toStringAsFixed(0)} pt(s)',
                color: EduColors.success,
              ),
              const Spacer(),
              if (answered)
                const Icon(Icons.check_circle_rounded, color: EduColors.success, size: 20)
              else
                const Icon(Icons.radio_button_unchecked_rounded, color: EduColors.muted, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            q.text,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: EduColors.text,
              height: 1.4,
            ),
          ),
          if (q.isMultiple)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Plusieurs réponses possibles',
                style: TextStyle(
                  fontSize: 12,
                  color: EduColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 12),
          ...List.generate(q.options.length, (oi) {
            final selected = _answers[i].contains(oi);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _toggleOption(i, oi),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? EduColors.infoBg : EduColors.neutralBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? EduColors.primary : EduColors.border,
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: q.isMultiple ? BoxShape.rectangle : BoxShape.circle,
                          borderRadius: q.isMultiple ? BorderRadius.circular(6) : null,
                          color: selected ? EduColors.primary : Colors.white,
                          border: Border.all(
                            color: selected ? EduColors.primary : EduColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: selected
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          q.options[oi],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? EduColors.text : EduColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
