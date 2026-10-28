import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/evaluations_mock_data.dart';
import '../models/evaluations_models.dart';
import '../widgets/eval_ui.dart';

class QuizWizardScreen extends StatefulWidget {
  final Quiz? existing;
  const QuizWizardScreen({super.key, this.existing});

  @override
  State<QuizWizardScreen> createState() => _QuizWizardScreenState();
}

class _QuizWizardScreenState extends State<QuizWizardScreen> {
  final _controller = EvaluationsController.instance;
  final _infoKey = GlobalKey<FormState>();
  int _step = 0;

  late final TextEditingController _title;
  late final TextEditingController _time;
  late final TextEditingController _attempts;
  late final TextEditingController _geminiHint;
  late String _courseId;
  late DateTime _availableFrom;
  late DateTime _dueDate;
  late List<QuizQuestion> _questions;
  String? _questionsError;
  bool _isGeneratingDraft = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (!_controller.isTeacher) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accès réservé aux enseignants (Règle 2).')),
        );
      });
    }
    final existing = widget.existing;
    final firstCourse = _controller.accessibleCourses.first;
    _title = TextEditingController(text: existing?.title ?? '');
    _time = TextEditingController(
      text: '${existing?.timeLimitMin ?? 15}',
    );
    _attempts = TextEditingController(
      text: '${existing?.attemptsAllowed ?? 1}',
    );
    _geminiHint = TextEditingController(text: 'Chapitre 2 — Structures de données');
    _courseId = existing?.courseId ?? firstCourse.id;
    _availableFrom = existing?.availableFrom ?? DateTime.now();
    _dueDate = existing?.dueDate ?? DateTime.now().add(const Duration(days: 7));
    _questions = existing?.questions.map((q) => q.copyWith()).toList() ?? [];
  }

  @override
  void dispose() {
    _title.dispose();
    _time.dispose();
    _attempts.dispose();
    _geminiHint.dispose();
    super.dispose();
  }

  bool _validate() {
    if (_step == 0) {
      final ok = _infoKey.currentState?.validate() ?? false;
      if (!ok) {
        _snack('Veuillez renseigner correctement tous les champs requis.');
        return false;
      }
      if (!_dueDate.isAfter(_availableFrom)) {
        _snack('La date d\'échéance doit être strictement postérieure à la date d\'ouverture.');
        return false;
      }
      return true;
    }
    if (_step == 1) {
      if (_questions.isEmpty) {
        setState(() => _questionsError = 'Ajoutez au moins une question au quiz.');
        _snack('Un quiz doit contenir au moins une question.');
        return false;
      }
      for (var i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        if (q.text.trim().length < 5) {
          setState(() => _questionsError = 'Question ${i + 1} : énoncé trop court (min. 5 car.).');
          return false;
        }
        if (q.options.any((o) => o.trim().isEmpty)) {
          setState(() => _questionsError = 'Question ${i + 1} : toutes les options doivent être remplies.');
          return false;
        }
        if (q.correct.isEmpty) {
          setState(() => _questionsError = 'Question ${i + 1} : cochez au moins une bonne réponse.');
          return false;
        }
        if (q.points <= 0 || q.points > 20) {
          setState(() => _questionsError = 'Question ${i + 1} : les points doivent être entre 0.5 et 20.');
          return false;
        }
      }
      setState(() => _questionsError = null);
      return true;
    }
    return true;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  LinkedCourse get _course =>
      _controller.courses.firstWhere((c) => c.id == _courseId);

  void _save({required bool publish}) {
    if (!_validate()) return;
    final quiz = Quiz(
      id: widget.existing?.id ?? 'quiz_${DateTime.now().millisecondsSinceEpoch}',
      courseId: _course.id,
      courseTitle: _course.title,
      teacherId: _controller.currentUserId,
      teacherName: _controller.currentUserName,
      title: _title.text.trim(),
      timeLimitMin: int.parse(_time.text.trim()),
      attemptsAllowed: int.parse(_attempts.text.trim()),
      availableFrom: _availableFrom,
      dueDate: _dueDate,
      isPublished: publish,
      questions: _questions,
    );
    _controller.upsertQuiz(quiz, publish: publish);
    Navigator.pop(context);
    _snack(
      publish
          ? 'Quiz publié avec succès (PATCH /quizzes/:id/publish). Les inscrits sont notifiés (L8).'
          : 'Quiz enregistré en brouillon avec succès.',
    );
  }

  Future<void> _pickDate({required bool opening}) async {
    final initial = opening ? _availableFrom : _dueDate;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime(2027, 12, 31),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (opening) {
        _availableFrom = value;
      } else {
        _dueDate = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const steps = ['1. Paramètres', '2. Questions & Barème', '3. Aperçu & Publication'];
    return Scaffold(
      backgroundColor: EduColors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Modifier le quiz' : 'Assistant de création de quiz',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: EduColors.text,
              ),
            ),
            const Text(
              'Enseignant · POST /quizzes · Brouillon Gemini (L4/L8)',
              style: TextStyle(fontSize: 11.5, color: EduColors.muted),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              children: List.generate(steps.length, (i) {
                final active = i <= _step;
                return Expanded(
                  child: Container(
                    height: 5,
                    margin: EdgeInsets.only(right: i == steps.length - 1 ? 0 : 6),
                    decoration: BoxDecoration(
                      color: active ? EduColors.primary : EduColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  steps[_step],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: EduColors.text,
                  ),
                ),
                const SizedBox(height: 14),
                if (_step == 0) _infoStep(),
                if (_step == 1) _questionsStep(),
                if (_step == 2) _previewStep(),
              ],
            ),
          ),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _infoStep() {
    return Form(
      key: _infoKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _courseId,
            decoration: evalInputDecoration(
              label: 'Cours associé (Liaison L4)',
              icon: Icons.menu_book_rounded,
            ),
            items: _controller.accessibleCourses
                .map(
                  (c) => DropdownMenuItem(
                    value: c.id,
                    child: Text('${c.title} (${c.level})'),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _courseId = v!),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _title,
            maxLength: 80,
            decoration: evalInputDecoration(
              label: 'Titre du quiz',
              hint: 'Ex. Évaluation rapide — Algorithmes de tri',
            ),
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.length < 5) return 'Titre requis (au moins 5 caractères).';
              if (RegExp(r'^\d+$').hasMatch(t)) {
                return 'Le titre ne peut pas comporter que des chiffres.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _time,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: evalInputDecoration(
                    label: 'Durée (minutes)',
                    icon: Icons.timer_outlined,
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1 || n > 180) {
                      return 'Entre 1 et 180 min.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _attempts,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: evalInputDecoration(
                    label: 'Tentatives permises',
                    icon: Icons.replay_rounded,
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1 || n > 5) return 'Entre 1 et 5 tentatives.';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _dateTile(
            'Date et heure d\'ouverture',
            _availableFrom,
            () => _pickDate(opening: true),
          ),
          const SizedBox(height: 8),
          _dateTile(
            'Date et heure d\'échéance',
            _dueDate,
            () => _pickDate(opening: false),
          ),
        ],
      ),
    );
  }

  Widget _dateTile(String label, DateTime value, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: EduColors.border),
      ),
      tileColor: Colors.white,
      leading: const Icon(Icons.event_rounded, color: EduColors.primary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
      subtitle: Text(formatDate(value), style: const TextStyle(fontSize: 12.5)),
      trailing: const Icon(Icons.edit_calendar_outlined, size: 20),
    );
  }

  Widget _questionsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: evalCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF7C3AED), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Brouillon Gemini API (Gratuit, simulé)',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Générez automatiquement des questions à partir d\'un chapitre de cours avant de les peaufiner.',
                style: TextStyle(fontSize: 12.5, color: EduColors.muted),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _geminiHint,
                decoration: evalInputDecoration(
                  label: 'Chapitre ou thème source',
                  hint: 'Ex. Arbres binaires et parcours',
                  icon: Icons.lightbulb_outline_rounded,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isGeneratingDraft ? null : _generateGeminiDraft,
                  icon: _isGeneratingDraft
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(_isGeneratingDraft ? 'Génération en cours…' : 'Générer un brouillon avec Gemini'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7C3AED),
                    side: const BorderSide(color: Color(0xFF7C3AED)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _addQuestion(QuestionType.qcm),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Ajouter un QCM'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _addQuestion(QuestionType.vraiFaux),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Ajouter Vrai/Faux'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        if (_questionsError != null)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: EduColors.dangerBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: EduColors.danger.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: EduColors.danger, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _questionsError!,
                    style: const TextStyle(
                      color: EduColors.danger,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        ..._questions.asMap().entries.map(_questionCard),
      ],
    );
  }

  Future<void> _generateGeminiDraft() async {
    setState(() => _isGeneratingDraft = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final generated = _controller.generateGeminiQuestions(_geminiHint.text);
    setState(() {
      _questions.addAll(generated);
      _questionsError = null;
      _isGeneratingDraft = false;
    });
    _snack('3 questions générées par Gemini. Vérifiez-les avant de publier.');
  }

  void _addQuestion(QuestionType type) {
    setState(() {
      _questions.add(
        QuizQuestion(
          id: 'q_${DateTime.now().millisecondsSinceEpoch}_${_questions.length}',
          type: type,
          text: '',
          options: type == QuestionType.vraiFaux
              ? ['Vrai', 'Faux']
              : ['Option 1', 'Option 2', 'Option 3', 'Option 4'],
          correct: const [],
          points: 5,
          explanation: '',
        ),
      );
    });
  }

  Widget _questionCard(MapEntry<int, QuizQuestion> entry) {
    final i = entry.key;
    final q = entry.value;
    return Container(
      key: ValueKey(q.id),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: evalCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(
                label: 'Question ${i + 1} · ${q.type.label}',
                color: EduColors.primary,
              ),
              const SizedBox(width: 8),
              StatusChip(
                label: '${q.points.toStringAsFixed(0)} pt(s)',
                color: EduColors.success,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Supprimer la question',
                onPressed: () => setState(() => _questions.removeAt(i)),
                icon: const Icon(Icons.delete_outline_rounded, color: EduColors.danger),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: q.text,
            maxLines: 2,
            decoration: evalInputDecoration(
              label: 'Énoncé de la question',
              hint: 'Saisissez la question…',
            ),
            onChanged: (v) => _questions[i] = q.copyWith(text: v),
          ),
          const SizedBox(height: 12),
          const Text(
            'Options et réponses attendues (cochez les bonnes réponses) :',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: EduColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          ...List.generate(q.options.length, (oi) {
            final isCorrect = q.correct.contains(oi);
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isCorrect ? EduColors.successBg.withValues(alpha: 0.5) : EduColors.neutralBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCorrect ? EduColors.success : EduColors.border,
                ),
              ),
              child: CheckboxListTile(
                value: isCorrect,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                activeColor: EduColors.success,
                title: TextFormField(
                  initialValue: q.options[oi],
                  enabled: q.type != QuestionType.vraiFaux,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (v) {
                    final opts = [...q.options];
                    opts[oi] = v;
                    _questions[i] = q.copyWith(options: opts);
                  },
                ),
                onChanged: (v) {
                  final next = [...q.correct];
                  if (v == true) {
                    if (q.type == QuestionType.vraiFaux) {
                      next.clear();
                      next.add(oi);
                    } else {
                      next.add(oi);
                    }
                  } else {
                    next.remove(oi);
                  }
                  setState(() => _questions[i] = q.copyWith(correct: next));
                },
              ),
            );
          }),
          if (q.type == QuestionType.qcm && q.options.length < 5)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    final opts = [...q.options, 'Nouvelle option'];
                    _questions[i] = q.copyWith(options: opts);
                  });
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Ajouter une option'),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: q.points.toStringAsFixed(0),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: evalInputDecoration(label: 'Points'),
                  onChanged: (v) {
                    _questions[i] = q.copyWith(points: double.tryParse(v) ?? 1);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: q.explanation,
                  decoration: evalInputDecoration(
                    label: 'Explication (correction)',
                    hint: 'Justification pour l\'étudiant…',
                  ),
                  onChanged: (v) => _questions[i] = q.copyWith(explanation: v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewStep() {
    final totalPts = _questions.fold<double>(0, (sum, q) => sum + q.points);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: evalCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusChip(
                    label: _course.title,
                    color: EduColors.primary,
                  ),
                  const Spacer(),
                  StatusChip(
                    label: 'Total : ${totalPts.toStringAsFixed(0)} pts',
                    color: EduColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _title.text.trim().isEmpty ? 'Sans titre' : _title.text.trim(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: EduColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Durée : ${_time.text} min · Tentatives : ${_attempts.text} · ${_questions.length} questions',
                style: const TextStyle(color: EduColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                'Ouverture : ${formatDate(_availableFrom)}',
                style: const TextStyle(fontSize: 12.5, color: EduColors.muted),
              ),
              Text(
                'Échéance : ${formatDate(_dueDate)}',
                style: const TextStyle(fontSize: 12.5, color: EduColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const SectionHeader(title: 'Aperçu des questions rédigées'),
        ..._questions.asMap().entries.map(
          (e) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: evalCardDecoration(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: EduColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Q${e.key + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: EduColors.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.value.text,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${e.value.options.length} options · Bonne(s) réponse(s) : ${e.value.correct.map((c) => e.value.options[c]).join(", ")}',
                        style: const TextStyle(fontSize: 12, color: EduColors.success, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${e.value.points.toStringAsFixed(0)} pt(s)',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: EduColors.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bottomBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_step > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step--),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text('Retour'),
                ),
              ),
            if (_step > 0) const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  if (_step < 2) {
                    if (_validate()) setState(() => _step++);
                  } else {
                    _save(publish: false);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: EduColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  minimumSize: const Size(0, 48),
                ),
                child: Text(_step < 2 ? 'Continuer' : 'Enregistrer brouillon'),
              ),
            ),
            if (_step == 2) ...[
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: EduColors.success,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: () => _save(publish: true),
                  child: const Text('Publier le quiz'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
