import 'dart:async';
import 'package:flutter/material.dart';
import '../data/evaluations_mock_data.dart';
import '../models/evaluations_models.dart';
import '../routes/evaluations_routes.dart';
import '../widgets/eval_ui.dart';

/// Écran étudiant de passage chronométré d'un quiz.
/// Démarre immédiatement une [QuizAttempt], décrémente un compte à rebours seconde par seconde
/// via [Timer.periodic] et déclenche la correction automatique à la soumission ou à l'expiration du temps.
class QuizTakeScreen extends StatefulWidget {
  final String quizId;
  const QuizTakeScreen({super.key, required this.quizId});

  @override
  State<QuizTakeScreen> createState() => _QuizTakeScreenState();
}

class _QuizTakeScreenState extends State<QuizTakeScreen> {
  final _controller = EvaluationsController.instance;

  /// Quiz affiché — nullable : peut être introuvable si la liste n'est pas
  /// (ou plus) chargée ; l'écran affiche alors un état vide au lieu de
  /// planter (l'ancien code appliquait un `!` direct dans initState).
  Quiz? _quiz;
  String? _attemptId;

  /// Matrice des indices d'options sélectionnés pour chaque question du quiz.
  List<List<int>> _answers = const [];

  /// Temps restant en secondes avant soumission forcée de la tentative.
  int _remainingSeconds = 0;

  /// Chronomètre périodique cadencé à 1 seconde pilotant le compte à rebours et la barre de progression.
  Timer? _timer;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final quiz = _controller.quizById(widget.quizId);
    if (quiz == null) {
      // Quiz introuvable (données rechargées, id obsolète…) : retour propre.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quiz introuvable.')),
        );
        Navigator.pop(context);
      });
      return;
    }
    _quiz = quiz;
    // Crée l'enregistrement de tentative côté contrôleur dès l'entrée sur l'écran.
    _createAttempt();
    _answers = List.generate(_quiz!.questions.length, (_) => <int>[]);
    _remainingSeconds = _quiz!.timeLimitMin * 60;
    // Décrémente le compteur chaque seconde et déclenche l'envoi automatique dès que le délai atteint zéro.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        _submit(auto: true);
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  /// Crée la tentative de façon asynchrone et retient son identifiant.
  Future<void> _createAttempt() async {
    final attempt = await _controller.startAttempt(widget.quizId);
    if (!mounted) return;
    setState(() => _attemptId = attempt?.id);
  }

  @override
  void dispose() {
    // Annule impérativement le Timer périodique à la destruction du widget pour éviter toute fuite mémoire.
    _timer?.cancel();
    super.dispose();
  }

  /// Met à jour la sélection d'une option `oi` pour la question `qi` :
  /// sélection unique sur un Vrai/Faux ou un QCM simple, bascule multi-choix lorsque `q.isMultiple` est vrai,
  /// puis synchronise immédiatement les réponses en cours dans [EvaluationsController].
  void _toggle(int qi, int oi) {
    final quiz = _quiz;
    if (quiz == null) return;
    final q = quiz.questions[qi];
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
    if (_attemptId != null) {
      _controller.saveAttemptAnswers(_attemptId!, _answers);
    }
  }

  /// Valide la tentative (manuellement ou automatiquement en fin de chronomètre),
  /// arrête le [Timer], invoque [EvaluationsController.submitAttempt] pour calculer la note sur 20
  /// et redirige vers `QuizResultsScreen` via `pushReplacementNamed`.
  Future<void> _submit({bool auto = false}) async {
    final quiz = _quiz;
    if (quiz == null) return;
    if (_submitting) return;
    // En soumission manuelle, vérifie qu'aucune question n'a été laissée sans réponse.
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

    try {
      // Si la tentative n'avait pas encore reçu d'ID (problème réseau), on en génère un local
      String targetAttemptId = _attemptId ?? 'att_local_${DateTime.now().millisecondsSinceEpoch}';
      if (_attemptId == null) {
        final newAttempt = await _controller.startAttempt(quiz.id);
        if (newAttempt != null) {
          targetAttemptId = newAttempt.id;
          _attemptId = targetAttemptId;
        }
      }

      _controller.saveAttemptAnswers(targetAttemptId, _answers);
      // Correction automatique et calcul du score ramené sur 20 dans le contrôleur.
      final attempt = await _controller.submitAttempt(targetAttemptId, _answers);
      if (!mounted) return;

      final score = attempt?.score ?? 0.0;
      // Remplace l'écran de passage dans la pile de navigation pour empêcher un retour arrière sur la copie close.
      Navigator.pushReplacementNamed(
        context,
        EvaluationsRoutes.quizResults,
        arguments: QuizResultsArgs(quizId: quiz.id, attemptId: targetAttemptId),
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Erreur lors de la soumission : $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de soumission : $e'),
            backgroundColor: EduColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quiz = _quiz;
    if (quiz == null) {
      // Quiz introuvable : état vide explicite au lieu d'un écran rouge.
      return const Scaffold(
        backgroundColor: EduColors.scaffold,
        body: Center(child: Text('Quiz introuvable')),
      );
    }
    // Fraction du temps écoulé (entre 0 et 1) alimentant le LinearProgressIndicator supérieur.
    final progress = 1 - (_remainingSeconds / (quiz.timeLimitMin * 60));
    final mm = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_remainingSeconds % 60).toString().padLeft(2, '0');
    // Passe l'affichage du compte à rebours et de la jauge en rouge sous la barre des 60 dernières secondes.
    final urgent = _remainingSeconds < 60;

    // Intercepte le geste ou bouton retour via PopScope pour demander confirmation dans un AlertDialog.
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
        if (leave == true && context.mounted) {
          Navigator.of(context).pop();
        }
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
                quiz.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: EduColors.text,
                ),
              ),
              Text(
                '${quiz.courseTitle} · ${_mmDisplay(mm, ss)}',
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
            // Barre de progression temporelle reflétant l'avancement du chronomètre.
            LinearProgressIndicator(
              value: progress.clamp(0, 1),
              color: urgent ? EduColors.danger : EduColors.primary,
              backgroundColor: EduColors.border,
              minHeight: 6,
            ),
            // Liste déroulante extensible générant une carte interactive par question.
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: quiz.questions.length,
                itemBuilder: (context, i) => _questionCard(quiz, i),
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

  /// Formate l'affichage textuel des minutes et secondes restantes dans l'AppBar.
  String _mmDisplay(String mm, String ss) => '$mm:$ss restantes';

  /// Construit la carte d'une question avec son barème et ses propositions sous forme de [FilterChip].
  Widget _questionCard(Quiz quiz, int i) {
    final q = quiz.questions[i];
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
          // Génère un FilterChip sélectionnable pour chaque proposition de réponse.
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
