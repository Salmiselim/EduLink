import 'package:flutter/material.dart';
import '../data/evaluations_mock_data.dart';
import '../models/evaluations_models.dart';
import '../widgets/eval_ui.dart';

class SubmissionGradeScreen extends StatefulWidget {
  final String submissionId;
  const SubmissionGradeScreen({super.key, required this.submissionId});

  @override
  State<SubmissionGradeScreen> createState() => _SubmissionGradeScreenState();
}

class _SubmissionGradeScreenState extends State<SubmissionGradeScreen> {
  final _controller = EvaluationsController.instance;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _grade;
  late final TextEditingController _feedback;

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
    final sub = _controller.submissionById(widget.submissionId);
    _grade = TextEditingController(
      text: sub?.grade != null
          ? (sub!.grade == sub.grade!.roundToDouble()
              ? sub.grade!.toInt().toString()
              : sub.grade!.toStringAsFixed(1))
          : '',
    );
    _feedback = TextEditingController(text: sub?.feedback ?? '');
  }

  @override
  void dispose() {
    _grade.dispose();
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sub = _controller.submissionById(widget.submissionId);
    if (sub == null) {
      return const Scaffold(
        body: Center(child: Text('Copie introuvable.')),
      );
    }
    final assignment = _controller.assignmentById(sub.assignmentId);
    if (assignment == null) {
      return const Scaffold(
        body: Center(child: Text('Devoir associé introuvable.')),
      );
    }

    return Scaffold(
      backgroundColor: EduColors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Correction de la copie',
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
            // Carte de la copie déposée
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
                        label: sub.isLate ? 'Rendu en retard' : 'Rendu dans les délais',
                        color: sub.isLate ? EduColors.danger : EduColors.success,
                        icon: sub.isLate ? Icons.warning_rounded : Icons.check_circle_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: EduColors.primary.withValues(alpha: 0.1),
                        child: Text(
                          sub.studentName.substring(0, 1),
                          style: const TextStyle(fontWeight: FontWeight.w800, color: EduColors.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sub.studentName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: EduColors.text,
                              ),
                            ),
                            Text(
                              '${assignment.title} · Déposé le ${formatDate(sub.submittedAt)}',
                              style: const TextStyle(fontSize: 12, color: EduColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Commentaire de l\'étudiant :',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: EduColors.neutralBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      sub.comment.isEmpty ? 'Aucun commentaire fourni.' : sub.comment,
                      style: const TextStyle(fontSize: 13, color: EduColors.textSecondary, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Fichiers remis (Cloudinary L10) :',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                  const SizedBox(height: 6),
                  ...sub.fileUrls.map(
                    (f) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: EduColors.border),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.picture_as_pdf_rounded, color: EduColors.danger),
                        title: Text(f, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Fichier étudiant téléchargeable', style: TextStyle(fontSize: 11)),
                        trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: EduColors.muted),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Ouverture simulée du fichier $f (MediaService L10).')),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            SectionHeader(
              title: 'Évaluation & Notation',
              subtitle: 'PATCH /submissions/:id/grade · Barème sur ${assignment.maxGrade.toStringAsFixed(0)}',
            ),

            TextFormField(
              controller: _grade,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: evalInputDecoration(
                label: 'Note attribuée / ${assignment.maxGrade.toStringAsFixed(0)}',
                hint: 'Ex. 16.5',
                icon: Icons.grade_outlined,
              ),
              validator: (v) {
                final cleaned = v?.replaceAll(',', '.').trim() ?? '';
                final n = double.tryParse(cleaned);
                if (n == null) return 'Veuillez saisir une note numérique valide.';
                if (n < 0 || n > assignment.maxGrade) {
                  return 'La note doit être comprise entre 0 et ${assignment.maxGrade.toStringAsFixed(0)}.';
                }
                return null;
              },
            ),

            const SizedBox(height: 14),
            TextFormField(
              controller: _feedback,
              maxLines: 5,
              maxLength: 400,
              decoration: evalInputDecoration(
                label: 'Remarques et appréciations (Feedback)',
                hint: 'Précisez les points forts, erreurs éventuelles et conseils pour progresser…',
                icon: Icons.feedback_outlined,
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.length < 10) {
                  return 'Le commentaire d\'évaluation doit comporter au moins 10 caractères.';
                }
                return null;
              },
            ),

            const SizedBox(height: 18),
            PrimaryCta(
              label: sub.status == SubmissionStatus.graded ? 'Mettre à jour la note' : 'Valider et publier la note',
              icon: Icons.check_circle_rounded,
              onPressed: () {
                if (!(_formKey.currentState?.validate() ?? false)) return;
                final gradeVal = double.parse(_grade.text.replaceAll(',', '.').trim());

                _controller.gradeSubmission(
                  submissionId: sub.id,
                  grade: gradeVal,
                  feedback: _feedback.text.trim(),
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: EduColors.success,
                    content: Text(
                      'Note ($gradeVal / ${assignment.maxGrade.toStringAsFixed(0)}) enregistrée. Notification FCM (L8) envoyée à ${sub.studentName}.',
                    ),
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
