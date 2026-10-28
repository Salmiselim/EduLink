import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/evaluations_mock_data.dart';
import '../models/evaluations_models.dart';
import '../widgets/eval_ui.dart';

class AssignmentWizardScreen extends StatefulWidget {
  final Assignment? existing;
  const AssignmentWizardScreen({super.key, this.existing});

  @override
  State<AssignmentWizardScreen> createState() => _AssignmentWizardScreenState();
}

class _AssignmentWizardScreenState extends State<AssignmentWizardScreen> {
  final _controller = EvaluationsController.instance;
  final _formKey = GlobalKey<FormState>();
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
    if (!_controller.isTeacher) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accès réservé aux enseignants (Règle 2).')),
        );
      });
    }
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

  bool _validateStep0() {
    return _formKey.currentState?.validate() ?? false;
  }

  bool _validateStep1() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (_attachments.isEmpty) {
      setState(() => _fileError = 'Veuillez joindre au moins une consigne (PDF Cloudinary L10).');
      return false;
    }
    setState(() => _fileError = null);
    return ok;
  }

  void _save() {
    if (!_validateStep1()) return;
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
      SnackBar(
        content: Text(
          widget.existing == null
              ? 'Devoir publié. Notification FCM (L8) envoyée aux étudiants inscrits.'
              : 'Devoir mis à jour avec succès.',
        ),
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime(2027, 12, 31),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate),
    );
    if (time == null || !mounted) return;
    setState(() {
      _dueDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    const steps = ['1. Consignes', '2. Échéance & Barème'];
    return Scaffold(
      backgroundColor: EduColors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? 'Nouveau devoir (dépôt)' : 'Modifier le devoir',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: EduColors.text,
              ),
            ),
            const Text(
              'Enseignant · POST /assignments · Notifications L8',
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
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
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
                  if (_step == 0) ...[
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
                        label: 'Titre du devoir',
                        hint: 'Ex. TP — Conception d\'un schéma relationnel',
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.length < 5) return 'Titre requis (au moins 5 caractères).';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _instructions,
                      maxLines: 6,
                      maxLength: 800,
                      decoration: evalInputDecoration(
                        label: 'Consignes détaillées',
                        hint: 'Décrivez précisément le travail demandé, les critères de notation et les formats de fichiers attendus…',
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.length < 20) {
                          return 'Les consignes doivent comporter au moins 20 caractères.';
                        }
                        return null;
                      },
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _maxGrade,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: evalInputDecoration(
                        label: 'Barème maximal',
                        hint: 'Ex. 20',
                        icon: Icons.grade_outlined,
                      ),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        if (n == null || n <= 0 || n > 100) {
                          return 'Note maximale entre 1 et 100.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: EduColors.border),
                      ),
                      title: const Text(
                        'Date et heure d\'échéance',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      subtitle: Text(formatDate(_dueDate), style: const TextStyle(fontSize: 12.5)),
                      leading: const Icon(Icons.event_available_rounded, color: EduColors.primary),
                      trailing: const Icon(Icons.edit_calendar_outlined, size: 20),
                      onTap: _pickDueDate,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: EduColors.border),
                      ),
                      child: SwitchListTile(
                        value: _allowLate,
                        activeThumbColor: EduColors.primary,
                        title: const Text(
                          'Autoriser les rendus en retard',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                        subtitle: const Text(
                          'Si activé, les étudiants peuvent déposer après la date limite avec la mention automatique « En retard » (isLate: true).',
                          style: TextStyle(fontSize: 12, color: EduColors.muted),
                        ),
                        onChanged: (v) => setState(() => _allowLate = v),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const SectionHeader(
                      title: 'Pièces jointes & Sujet (MediaService L10)',
                      subtitle: 'Fichiers PDF associés au devoir',
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _attachments.add('consigne_devoir_${_attachments.length + 1}.pdf');
                          _fileError = null;
                        });
                      },
                      icon: const Icon(Icons.attach_file_rounded),
                      label: const Text('Joindre une consigne (PDF Cloudinary L10)'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    if (_fileError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _fileError!,
                          style: const TextStyle(color: EduColors.danger, fontWeight: FontWeight.w600, fontSize: 12.5),
                        ),
                      ),
                    const SizedBox(height: 8),
                    ..._attachments.map(
                      (f) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: evalCardDecoration(),
                        child: ListTile(
                          leading: const Icon(Icons.picture_as_pdf_rounded, color: EduColors.danger),
                          title: Text(f, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close_rounded, color: EduColors.muted, size: 18),
                            onPressed: () => setState(() => _attachments.remove(f)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _step = 0),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          minimumSize: const Size(0, 48),
                        ),
                        child: const Text('Retour'),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryCta(
                      label: _step == 0 ? 'Continuer' : (widget.existing == null ? 'Publier le devoir' : 'Enregistrer les modifications'),
                      icon: _step == 0 ? Icons.arrow_forward_rounded : Icons.check_circle_rounded,
                      onPressed: () {
                        if (_step == 0) {
                          if (_validateStep0()) {
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
          ),
        ],
      ),
    );
  }
}
