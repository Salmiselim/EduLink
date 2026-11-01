import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/evaluations_mock_data.dart';
import '../models/evaluations_models.dart';
import '../widgets/eval_ui.dart';

/// Assistant enseignant en trois étapes pour créer ou modifier un [Quiz] :
/// 0. Paramètres généraux et dates · 1. Éditeur de questions et génération de brouillon · 2. Aperçu et publication.
class QuizWizardScreen extends StatefulWidget {
  final Quiz? existing;
  const QuizWizardScreen({super.key, this.existing});

  @override
  State<QuizWizardScreen> createState() => _QuizWizardScreenState();
}

class _QuizWizardScreenState extends State<QuizWizardScreen> {
  final _controller = EvaluationsController.instance;

  /// Clé globale de validation rattachée au [Form] de la première étape (`_infoStep`).
  final _infoKey = GlobalKey<FormState>();

  /// Indice de l'étape active (`0`, `1` ou `2`).
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

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    // Sécurité d'accès : renvoie immédiatement en arrière si l'utilisateur actif n'est pas enseignant.
    if (!_controller.isTeacher) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
      });
    }
    // Préremplit les champs et clone la liste de questions lorsqu'un quiz existant est modifié.
    final existing = widget.existing;
    final firstCourse = _controller.accessibleCourses.first;
    _title = TextEditingController(text: existing?.title ?? '');
    _time = TextEditingController(
      text: '${existing?.timeLimitMin ?? 15}',
    );
    _attempts = TextEditingController(
      text: '${existing?.attemptsAllowed ?? 1}',
    );
    _geminiHint = TextEditingController(text: 'Chapitre listes et piles');
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

  /// Valide les contraintes métier propres à l'étape courante avant d'autoriser le passage à la suivante
  /// ou la sauvegarde finale du quiz.
  bool _validate() {
    if (_step == 0) {
      final ok = _infoKey.currentState?.validate() ?? false;
      if (!ok) {
        _snack('Vérifiez le titre, la durée, les tentatives et les dates.');
      }
      // Vérifie la cohérence chronologique entre la date d'ouverture et l'échéance de fermeture.
      if (_dueDate.isBefore(_availableFrom)) {
        _snack('L\'échéance doit être postérieure à la date d\'ouverture.');
        return false;
      }
      return ok;
    }
    if (_step == 1) {
      if (_questions.isEmpty) {
        setState(() => _questionsError = 'Ajoutez au moins une question.');
        _snack('Un quiz doit contenir au moins une question.');
        return false;
      }
      // Contrôle individuel de chaque question : longueur d'énoncé, options non vides, réponse cochée et barème valide.
      for (final q in _questions) {
        if (q.text.trim().length < 10) {
          setState(
            () => _questionsError = 'Chaque énoncé doit faire au moins 10 caractères.',
          );
          return false;
        }
        if (q.options.any((o) => o.trim().isEmpty)) {
          setState(() => _questionsError = 'Toutes les options doivent être renseignées.');
          return false;
        }
        if (q.correct.isEmpty) {
          setState(() => _questionsError = 'Cochez au moins une bonne réponse.');
          return false;
        }
        if (q.points <= 0 || q.points > 20) {
          setState(() => _questionsError = 'Les points doivent être entre 0.5 et 20.');
          return false;
        }
      }
      setState(() => _questionsError = null);
      return true;
    }
    return true;
  }

  /// Affiche un message d'information ou d'erreur dans un [SnackBar] en bas de l'écran.
  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// Résout l'objet [LinkedCourse] correspondant à l'identifiant sélectionné `_courseId`.
  LinkedCourse get _course =>
      _controller.courses.firstWhere((c) => c.id == _courseId);

  /// Construit l'instance finale de [Quiz] et l'enregistre dans [EvaluationsController.upsertQuiz]
  /// soit en brouillon (`publish: false`), soit directement publiée (`publish: true`).
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
          ? 'Quiz publié (PATCH /quizzes/:id/publish). Les inscrits seront notifiés (L8).'
          : 'Quiz enregistré en brouillon.',
    );
  }

  /// Enchaîne un sélecteur de date (`showDatePicker`) et d'heure (`showTimePicker`)
  /// pour définir précisément la fenêtre d'ouverture ou l'échéance du quiz.
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
    const steps = ['1. Infos', '2. Questions', '3. Aperçu'];
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
              'Enseignant uniquement · POST /quizzes · Gemini (brouillon)',
              style: TextStyle(fontSize: 11.5, color: EduColors.muted),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Indicateur visuel en 3 segments horizontaux (`Expanded`) illustrant l'étape active.
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(
              children: List.generate(steps.length, (i) {
                final active = i <= _step;
                return Expanded(
                  child: Container(
                    height: 6,
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
          // Contenu déroulant affichant le sous-formulaire correspondant à `_step`.
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

  /// Étape 0 : formulaire des métadonnées générales du quiz (cours, titre, durée, tentatives et dates).
  Widget _infoStep() {
    return Form(
      key: _infoKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        children: [
          // Choix du cours auquel rattacher l'évaluation parmi les cours gérés par l'enseignant.
          DropdownButtonFormField<String>(
            initialValue: _courseId,
            decoration: evalInputDecoration(
              label: 'Cours lié (L4)',
              icon: Icons.menu_book_rounded,
            ),
            items: _controller.accessibleCourses
                .map(
                  (c) => DropdownMenuItem(
                    value: c.id,
                    child: Text('${c.title} · ${c.level}'),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _courseId = v!),
          ),
          const SizedBox(height: 12),
          // Saisie du titre rejetant les chaînes trop courtes ou purement numériques.
          TextFormField(
            controller: _title,
            maxLength: 80,
            decoration: evalInputDecoration(
              label: 'Titre du quiz',
              hint: 'Ex. Structures linéaires',
            ),
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.length < 5) return 'Titre obligatoire (5 à 80 caractères).';
              if (RegExp(r'^\d+$').hasMatch(t)) {
                return 'Le titre ne peut pas être uniquement numérique.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          // Deux champs numériques côte à côte (`Expanded`) pour la durée en minutes et le plafond de tentatives.
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _time,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: evalInputDecoration(
                    label: 'Durée (min)',
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
                    label: 'Tentatives',
                    icon: Icons.replay_rounded,
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1 || n > 5) return 'Entre 1 et 5.';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _dateTile(
            'Ouverture',
            _availableFrom,
            () => _pickDate(opening: true),
          ),
          const SizedBox(height: 8),
          _dateTile('Échéance', _dueDate, () => _pickDate(opening: false)),
        ],
      ),
    );
  }

  /// Tuile cliquable affichant une date formatée et déclenchant le sélecteur date/heure associé.
  Widget _dateTile(String label, DateTime value, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: EduColors.border),
      ),
      tileColor: Colors.white,
      leading: const Icon(Icons.event_rounded, color: EduColors.primary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(formatDate(value)),
      trailing: const Icon(Icons.edit_calendar_outlined),
    );
  }

  /// Étape 1 : génération assistée de questions de départ et ajout/édition manuelle de QCM ou Vrai/Faux.
  Widget _questionsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encart de préremplissage automatique ajoutant 3 questions via `generateGeminiQuestions`.
        Container(
          padding: const EdgeInsets.all(14),
          decoration: evalCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Brouillon Gemini (API simulée)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _geminiHint,
                decoration: evalInputDecoration(
                  label: 'Chapitre source',
                  hint: 'Ex. Chapitre 2 — Récursivité',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _questions.addAll(
                      _controller.generateGeminiQuestions(_geminiHint.text),
                    );
                    _questionsError = null;
                  });
                  _snack('3 questions générées. Relisez-les avant publication.');
                },
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Générer un brouillon'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Barre de puces d'action (`Wrap` + `ActionChip`) permettant d'insérer un QCM ou un Vrai/Faux vierge.
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Ajouter un QCM'),
              onPressed: () => _addQuestion(QuestionType.qcm),
            ),
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Ajouter Vrai/Faux'),
              onPressed: () => _addQuestion(QuestionType.vraiFaux),
            ),
          ],
        ),
        if (_questionsError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _questionsError!,
              style: const TextStyle(
                color: EduColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 8),
        ..._questions.asMap().entries.map(_questionCard),
      ],
    );
  }

  /// Ajoute une nouvelle question vierge à `_questions` avec options préconfigurées selon [type].
  void _addQuestion(QuestionType type) {
    setState(() {
      _questions.add(
        QuizQuestion(
          id: 'q_${DateTime.now().millisecondsSinceEpoch}',
          type: type,
          text: '',
          options: type == QuestionType.vraiFaux
              ? ['Vrai', 'Faux']
              : ['', '', '', ''],
          correct: const [],
          points: 5,
          explanation: '',
        ),
      );
    });
  }

  /// Construit la carte d'édition d'une question identifiée par `ValueKey(q.id)` :
  /// énoncé, propositions cochables via `CheckboxListTile`, barème en points et explication de corrigé.
  Widget _questionCard(MapEntry<int, QuizQuestion> entry) {
    final i = entry.key;
    final q = entry.value;
    return Container(
      key: ValueKey(q.id),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: evalCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(
                label: 'Q${i + 1} · ${q.type.label}',
                color: EduColors.primary,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Supprimer',
                onPressed: () => setState(() => _questions.removeAt(i)),
                icon: const Icon(Icons.delete_outline_rounded, color: EduColors.danger),
              ),
            ],
          ),
          TextFormField(
            initialValue: q.text,
            maxLines: 2,
            decoration: evalInputDecoration(label: 'Énoncé'),
            onChanged: (v) => _questions[i] = q.copyWith(text: v),
          ),
          const SizedBox(height: 8),
          // Chaque option combine un champ d'intitulé (verrouillé sur Vrai/Faux) et une case à cocher marquant les réponses exactes.
          ...List.generate(q.options.length, (oi) {
            final selected = q.correct.contains(oi);
            return CheckboxListTile(
              value: selected,
              contentPadding: EdgeInsets.zero,
              title: TextFormField(
                initialValue: q.options[oi],
                enabled: q.type != QuestionType.vraiFaux,
                decoration: InputDecoration(
                  hintText: 'Option ${oi + 1}',
                  border: const UnderlineInputBorder(),
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
                  // Un Vrai/Faux n'admet qu'une seule réponse exacte à la fois.
                  if (q.type == QuestionType.vraiFaux) {
                    next
                      ..clear()
                      ..add(oi);
                  } else {
                    next.add(oi);
                  }
                } else {
                  next.remove(oi);
                }
                setState(() => _questions[i] = q.copyWith(correct: next));
              },
            );
          }),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: q.points.toStringAsFixed(0),
                  keyboardType: TextInputType.number,
                  decoration: evalInputDecoration(label: 'Points'),
                  onChanged: (v) {
                    _questions[i] = q.copyWith(points: double.tryParse(v) ?? 0);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: q.explanation,
                  decoration: evalInputDecoration(label: 'Explication'),
                  onChanged: (v) =>
                      _questions[i] = q.copyWith(explanation: v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Étape 2 : récapitulatif en lecture seule des paramètres et des questions avant enregistrement.
  Widget _previewStep() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: evalCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            '${_course.title} · ${_time.text} min · ${_attempts.text} tentative(s) · ${_questions.length} question(s)',
            style: const TextStyle(color: EduColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text('Ouverture : ${formatDate(_availableFrom)}'),
          Text('Échéance : ${formatDate(_dueDate)}'),
          const Divider(height: 24),
          ..._questions.asMap().entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Q${e.key + 1}. ${e.value.text} (${e.value.points.toStringAsFixed(0)} pts)',
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Barre d'actions inférieure gérant la navigation entre étapes et le choix final Brouillon / Publier.
  Widget _bottomBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step--),
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
              child: Text(_step < 2 ? 'Continuer' : 'Brouillon'),
            ),
          ),
          if (_step == 2) ...[
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: EduColors.success,
                ),
                onPressed: () => _save(publish: true),
                child: const Text('Publier'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
