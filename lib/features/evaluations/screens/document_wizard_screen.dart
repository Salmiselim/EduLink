import 'package:flutter/material.dart';
import '../data/evaluations_mock_data.dart';
import '../models/evaluations_models.dart';
import '../widgets/eval_ui.dart';

class DocumentWizardScreen extends StatefulWidget {
  final CourseDocument? existing;
  const DocumentWizardScreen({super.key, this.existing});

  @override
  State<DocumentWizardScreen> createState() => _DocumentWizardScreenState();
}

class _DocumentWizardScreenState extends State<DocumentWizardScreen> {
  final _controller = EvaluationsController.instance;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late String _courseId;
  late DocumentFolder _folder;
  String? _fileUrl;
  String? _fileError;

  @override
  void initState() {
    super.initState();
    if (!_controller.isTeacher) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pop(context));
    }
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _courseId = e?.courseId ?? _controller.accessibleCourses.first.id;
    _folder = e?.folder ?? DocumentFolder.polycopies;
    _fileUrl = e?.fileUrl;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EduColors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          widget.existing == null ? 'Nouveau document' : 'Modifier le document',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: EduColors.text,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _courseId,
              decoration: evalInputDecoration(label: 'Cours'),
              items: _controller.accessibleCourses
                  .map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.title)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _courseId = v!),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: DocumentFolder.values
                  .map(
                    (f) => ChoiceChip(
                      label: Text(f.label),
                      selected: _folder == f,
                      onSelected: (_) => setState(() => _folder = f),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              maxLength: 80,
              decoration: evalInputDecoration(label: 'Titre'),
              validator: (v) {
                if ((v?.trim().length ?? 0) < 5) {
                  return 'Titre obligatoire (5 à 80 caractères).';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 3,
              maxLength: 300,
              decoration: evalInputDecoration(label: 'Description'),
              validator: (v) {
                if ((v?.trim().length ?? 0) < 10) {
                  return 'Description obligatoire (10 à 300 caractères).';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _fileUrl = 'document_${DateTime.now().millisecondsSinceEpoch}.pdf';
                  _fileError = null;
                });
              },
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(_fileUrl ?? 'Choisir un fichier PDF (L10, simulé)'),
            ),
            if (_fileError != null)
              Text(_fileError!, style: const TextStyle(color: EduColors.danger)),
            const SizedBox(height: 20),
            PrimaryCta(
              label: 'Enregistrer le document',
              icon: Icons.save_rounded,
              onPressed: () {
                if (_fileUrl == null) {
                  setState(() => _fileError = 'Un fichier est obligatoire.');
                  return;
                }
                if (!(_formKey.currentState?.validate() ?? false)) return;
                final course =
                    _controller.courses.firstWhere((c) => c.id == _courseId);
                _controller.upsertDocument(
                  CourseDocument(
                    id: widget.existing?.id ??
                        'doc_${DateTime.now().millisecondsSinceEpoch}',
                    courseId: course.id,
                    courseTitle: course.title,
                    teacherId: _controller.currentUserId,
                    teacherName: _controller.currentUserName,
                    title: _title.text.trim(),
                    description: _description.text.trim(),
                    folder: _folder,
                    fileUrl: _fileUrl!,
                    order: widget.existing?.order ??
                        _controller.documents.length + 1,
                    visibleFrom: DateTime.now(),
                    downloadsCount: widget.existing?.downloadsCount ?? 0,
                  ),
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Document enregistré dans le dossier du cours.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
