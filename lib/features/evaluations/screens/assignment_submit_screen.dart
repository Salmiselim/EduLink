import 'package:flutter/material.dart';
import '../data/evaluations_mock_data.dart';
import '../widgets/eval_ui.dart';

class AssignmentSubmitScreen extends StatefulWidget {
  final String assignmentId;
  const AssignmentSubmitScreen({super.key, required this.assignmentId});

  @override
  State<AssignmentSubmitScreen> createState() => _AssignmentSubmitScreenState();
}

class _AssignmentSubmitScreenState extends State<AssignmentSubmitScreen> {
  final _controller = EvaluationsController.instance;
  final _formKey = GlobalKey<FormState>();
  final _comment = TextEditingController();
  final List<String> _files = [];
  String? _fileError;

  @override
  void initState() {
    super.initState();
    final existing = _controller.submissionFor(
      widget.assignmentId,
      _controller.currentUserId,
    );
    if (existing != null) {
      _comment.text = existing.comment;
      _files.addAll(existing.fileUrls);
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assignment = _controller.assignmentById(widget.assignmentId);
    if (assignment == null) {
      return const Scaffold(
        body: Center(child: Text('Devoir introuvable.')),
      );
    }
    final isLate = DateTime.now().isAfter(assignment.dueDate);
    final canSubmit = _controller.canSubmitAssignment(assignment);

    return Scaffold(
      backgroundColor: EduColors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Dépôt de devoir',
          style: TextStyle(
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
            // Carte du devoir
            Container(
              padding: const EdgeInsets.all(18),
              decoration: evalCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StatusChip(
                        label: assignment.courseTitle,
                        color: EduColors.primary,
                      ),
                      const Spacer(),
                      StatusChip(
                        label: isLate
                            ? (assignment.allowLate ? 'Retard toléré' : 'Date limite dépassée')
                            : 'Dans les délais',
                        color: isLate ? EduColors.danger : EduColors.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    assignment.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: EduColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enseignant : ${assignment.teacherName} · Barème : ${assignment.maxGrade.toStringAsFixed(0)} pts',
                    style: const TextStyle(color: EduColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Consignes :',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    assignment.instructions,
                    style: const TextStyle(
                      height: 1.5,
                      fontSize: 13.5,
                      color: EduColors.textSecondary,
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.alarm_rounded, size: 16, color: EduColors.muted),
                      const SizedBox(width: 6),
                      Text(
                        'Date limite : ${formatDate(assignment.dueDate)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isLate ? EduColors.danger : EduColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (assignment.attachments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Fichiers joints par l\'enseignant :',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                    const SizedBox(height: 6),
                    ...assignment.attachments.map(
                      (att) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: EduColors.neutralBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.picture_as_pdf_rounded, color: EduColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                att,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const Text(
                              'Consigne L10',
                              style: TextStyle(fontSize: 11, color: EduColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 18),
            const SectionHeader(
              title: 'Vos fichiers de rendu',
              subtitle: 'Téléversez vos copies, codes ou rapports (L10)',
            ),

            OutlinedButton.icon(
              onPressed: canSubmit
                  ? () {
                      setState(() {
                        final idx = _files.length + 1;
                        _files.add('rendu_${_controller.currentUserId}_f$idx.pdf');
                        _fileError = null;
                      });
                    }
                  : null,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Ajouter un fichier (Cloudinary L10 simulé)'),
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
            ..._files.map(
              (f) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: evalCardDecoration(),
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file_rounded, color: EduColors.primary),
                  title: Text(f, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Fichier prêt pour téléversement', style: TextStyle(fontSize: 11.5)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded, color: EduColors.muted, size: 18),
                    onPressed: () => setState(() => _files.remove(f)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),
            TextFormField(
              controller: _comment,
              maxLines: 4,
              maxLength: 300,
              decoration: evalInputDecoration(
                label: 'Commentaire pour l\'enseignant',
                hint: 'Détaillez brièvement votre approche, structure du code ou remarques…',
                icon: Icons.chat_bubble_outline_rounded,
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.length < 10) {
                  return 'Le commentaire doit comporter au moins 10 caractères.';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),
            PrimaryCta(
              label: canSubmit ? 'Soumettre mon travail' : 'Dépôt fermé (échéance dépassée)',
              icon: Icons.send_rounded,
              onPressed: canSubmit
                  ? () {
                      if (_files.isEmpty) {
                        setState(() => _fileError = 'Veuillez ajouter au moins un fichier.');
                        return;
                      }
                      if (!(_formKey.currentState?.validate() ?? false)) return;

                      _controller.submitAssignment(
                        assignmentId: assignment.id,
                        files: List.of(_files),
                        comment: _comment.text.trim(),
                      );

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: isLate ? EduColors.warning : EduColors.success,
                          content: Text(
                            isLate
                                ? 'Dépôt enregistré avec la mention « En retard » (L8 notifié).'
                                : 'Devoir rendu dans les délais avec succès (L8 notifié).',
                          ),
                        ),
                      );
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
