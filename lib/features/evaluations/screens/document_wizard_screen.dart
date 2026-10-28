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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? 'Nouveau document' : 'Modifier le document',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: EduColors.text,
              ),
            ),
            const Text(
              'Enseignant · Espace Blackboard · POST /documents',
              style: TextStyle(fontSize: 11.5, color: EduColors.muted),
            ),
          ],
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
            const SizedBox(height: 16),
            const Text(
              'Dossier de classement (façon Blackboard) :',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: EduColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: DocumentFolder.values
                  .map(
                    (f) => ChoiceChip(
                      avatar: Icon(f.icon, size: 16, color: _folder == f ? Colors.white : f.color),
                      label: Text(f.label),
                      selected: _folder == f,
                      selectedColor: f.color,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _folder == f ? Colors.white : EduColors.textSecondary,
                      ),
                      onSelected: (_) => setState(() => _folder = f),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              maxLength: 80,
              decoration: evalInputDecoration(
                label: 'Titre du document',
                hint: 'Ex. Polycopié de cours — Chapitre 3',
                icon: Icons.title_rounded,
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.length < 5) return 'Titre requis (au moins 5 caractères).';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 4,
              maxLength: 300,
              decoration: evalInputDecoration(
                label: 'Description du contenu',
                hint: 'Précisez le contenu pédagogique, les chapitres concernés ou les exercices traités…',
                icon: Icons.description_outlined,
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.length < 10) {
                  return 'Description requise (au moins 10 caractères).';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            const SectionHeader(
              title: 'Fichier pédagogique (MediaService L10)',
              subtitle: 'Fichier PDF, annale ou corrigé',
            ),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _fileUrl = 'doc_${_folder.name}_${DateTime.now().millisecondsSinceEpoch}.pdf';
                  _fileError = null;
                });
              },
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(_fileUrl ?? 'Téléverser un fichier PDF (Cloudinary L10)'),
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
            if (_fileUrl != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: evalCardDecoration(),
                child: ListTile(
                  leading: Icon(_folder.icon, color: _folder.color),
                  title: Text(_fileUrl!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text('${_folder.label} · Prêt pour publication', style: const TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.check_circle_rounded, color: EduColors.success, size: 20),
                ),
              ),
            const SizedBox(height: 24),
            PrimaryCta(
              label: widget.existing == null ? 'Publier le document' : 'Enregistrer les modifications',
              icon: Icons.save_rounded,
              onPressed: () {
                if (_fileUrl == null) {
                  setState(() => _fileError = 'Veuillez téléverser un fichier PDF.');
                  return;
                }
                if (!(_formKey.currentState?.validate() ?? false)) return;

                final course = _controller.courses.firstWhere((c) => c.id == _courseId);
                _controller.upsertDocument(
                  CourseDocument(
                    id: widget.existing?.id ?? 'doc_${DateTime.now().millisecondsSinceEpoch}',
                    courseId: course.id,
                    courseTitle: course.title,
                    teacherId: _controller.currentUserId,
                    teacherName: _controller.currentUserName,
                    title: _title.text.trim(),
                    description: _description.text.trim(),
                    folder: _folder,
                    fileUrl: _fileUrl!,
                    order: widget.existing?.order ?? _controller.documents.length + 1,
                    visibleFrom: DateTime.now(),
                    downloadsCount: widget.existing?.downloadsCount ?? 0,
                  ),
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: EduColors.success,
                    content: Text('Document publié dans le dossier ${_folder.label} du cours ${course.title}.'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
