import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/evaluations_mock_data.dart';
import '../models/evaluations_models.dart';
import '../widgets/eval_ui.dart';

/// Assistant enseignant en deux étapes permettant de créer ou de modifier un [Assignment].
/// Étape 0 : cours rattaché, titre et consignes. Étape 1 : barème, échéance, tolérance au retard et PDF joint.
class AssignmentWizardScreen extends StatefulWidget {
  final Assignment? existing;
  const AssignmentWizardScreen({super.key, this.existing});

  @override
  State<AssignmentWizardScreen> createState() => _AssignmentWizardScreenState();
}

class _AssignmentWizardScreenState extends State<AssignmentWizardScreen> {
  final _controller = EvaluationsController.instance;

  /// Clé globale de validation associée au [Form] englobant les étapes de l'assistant.
  final _formKey = GlobalKey<FormState>();

  /// Indice de l'étape active (`0` pour les informations générales, `1` pour le barème et les pièces jointes).
  int _step = 0;

  late final TextEditingController _title;
  late final TextEditingController _instructions;
  late final TextEditingController _maxGrade;
  late String _courseId;
  late DateTime _dueDate;
  late bool _allowLate;
  final List<String> _attachments = [];
  String? _fileError;

  @override
  void initState() {
    super.initState();
    // Garde d'accès : referme immédiatement l'écran si l'utilisateur courant n'est pas enseignant.
    if (!_controller.isTeacher) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pop(context));
    }
    // Initialise les contrôleurs avec les valeurs du devoir existant en édition ou des valeurs par défaut.
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _instructions = TextEditingController(text: e?.instructions ?? '');
    _maxGrade = TextEditingController(
      text: e?.maxGrade.toStringAsFixed(0) ?? '20',
    );
    _courseId = e?.courseId ?? _controller.accessibleCourses.first.id;
    _dueDate = e?.dueDate ?? DateTime.now().add(const Duration(days: 7));
    _allowLate = e?.allowLate ?? true;
    if (e != null) _attachments.addAll(e.attachments);
  }

  @override
  void dispose() {
    _title.dispose();
    _instructions.dispose();
    _maxGrade.dispose();
    super.dispose();
  }

  /// Valide à la fois les champs du [Form] et la présence d'au moins un support de consigne joint.
  bool _validate() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (_attachments.isEmpty) {
      setState(() => _fileError = 'Ajoutez au moins une consigne (PDF simulé).');
      return false;
    }
    setState(() => _fileError = null);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Titre, consignes (min. 20 car.) et note max sont requis.'),
        ),
      );
    }
    return ok;
  }

  /// Persiste le devoir créé ou modifié dans [EvaluationsController.upsertAssignment] puis revient à l'écran précédent.
  void _save() {
    if (!_validate()) return;
    final course = _controller.courses.firstWhere((c) => c.id == _courseId);
    _controller.upsertAssignment(
      Assignment(
        id: widget.existing?.id ??
            'asg_${DateTime.now().millisecondsSinceEpoch}',
        courseId: course.id,
        courseTitle: course.title,
        teacherId: _controller.currentUserId,
        teacherName: _controller.currentUserName,
        title: _title.text.trim(),
        instructions: _instructions.text.trim(),
        attachments: List.of(_attachments),
        dueDate: _dueDate,
        maxGrade: double.parse(_maxGrade.text.trim()),
        allowLate: _allowLate,
      ),
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Devoir enregistré. Notification L8 envoyée.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EduColors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          widget.existing == null ? 'Nouveau devoir' : 'Modifier le devoir',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: EduColors.text,
          ),
        ),
      ),
      body: Column(
        children: [
          // Barre de progression linéaire indiquant l'avancement sur les 2 étapes du wizard.
          LinearProgressIndicator(
            value: (_step + 1) / 2,
            color: EduColors.primary,
            backgroundColor: EduColors.border,
            minHeight: 6,
          ),
          // Zone centrale extensible accueillant le formulaire déroulant.
          Expanded(
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_step == 0) ...[
                    // Sélecteur déroulant rattachant le devoir à l'un des cours de l'enseignant.
                    DropdownButtonFormField<String>(
                      initialValue: _courseId,
                      decoration: evalInputDecoration(label: 'Cours (L4)'),
                      items: _controller.accessibleCourses
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.title),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _courseId = v!),
                    ),
                    const SizedBox(height: 12),
                    // Saisie du titre avec contrôle de longueur minimale et maximale.
                    TextFormField(
                      controller: _title,
                      maxLength: 80,
                      decoration: evalInputDecoration(label: 'Titre du devoir'),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.length < 5) return 'Titre : 5 à 80 caractères.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // Saisie multiligne des consignes détaillées du travail demandé.
                    TextFormField(
                      controller: _instructions,
                      maxLines: 5,
                      maxLength: 800,
                      decoration: evalInputDecoration(
                        label: 'Consignes',
                        hint: 'Décrivez le travail attendu…',
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.length < 20) {
                          return 'Consignes obligatoires (20 à 800 caractères).';
                        }
                        return null;
                      },
                    ),
                  ] else ...[
                    // Champ numérique restreint aux chiffres définissant le barème maximal (1 à 20).
                    TextFormField(
                      controller: _maxGrade,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: evalInputDecoration(
                        label: 'Note maximale',
                        icon: Icons.grade_outlined,
                      ),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        if (n == null || n <= 0 || n > 20) {
                          return 'Note max entre 1 et 20.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // Sélecteur de date limite ouvrant un DatePicker et fixant l'heure à 23h59.
                    ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: EduColors.border),
                      ),
                      title: const Text('Échéance'),
                      subtitle: Text(formatDate(_dueDate)),
                      trailing: const Icon(Icons.event_rounded),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _dueDate,
                          firstDate: DateTime(2026),
                          lastDate: DateTime(2027),
                        );
                        if (d == null || !mounted) return;
                        setState(
                          () => _dueDate = DateTime(d.year, d.month, d.day, 23, 59),
                        );
                      },
                    ),
                    // Interrupteur contrôlant la politique `allowLate` pour les remises après échéance.
                    SwitchListTile(
                      value: _allowLate,
                      title: const Text('Autoriser les rendus en retard'),
                      subtitle: const Text(
                        'Le retard sera détecté automatiquement (isLate).',
                      ),
                      onChanged: (v) => setState(() => _allowLate = v),
                    ),
                    const SizedBox(height: 8),
                    // Ajout simulé de fichiers PDF d'énoncé rattachés au devoir.
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _attachments.add(
                            'consigne_${_attachments.length + 1}.pdf',
                          );
                          _fileError = null;
                        });
                      },
                      icon: const Icon(Icons.attach_file_rounded),
                      label: const Text('Joindre un PDF (MediaService L10, simulé)'),
                    ),
                    if (_fileError != null)
                      Text(
                        _fileError!,
                        style: const TextStyle(color: EduColors.danger),
                      ),
                    ..._attachments.map(
                      (f) => ListTile(
                        leading: const Icon(Icons.picture_as_pdf_rounded),
                        title: Text(f),
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() => _attachments.remove(f)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Barre d'actions inférieure permettant de revenir à l'étape 0 ou de valider l'étape courante.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _step = 0),
                      child: const Text('Retour'),
                    ),
                  ),
                if (_step > 0) const SizedBox(width: 10),
                Expanded(
                  child: PrimaryCta(
                    label: _step == 0 ? 'Continuer' : 'Publier le devoir',
                    onPressed: () {
                      if (_step == 0) {
                        if (_formKey.currentState?.validate() ?? false) {
                          setState(() => _step = 1);
                        }
                      } else {
                        _save();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
