import 'package:flutter/material.dart';
import '../data/evaluations_mock_data.dart';
import '../widgets/eval_ui.dart';

/// Écran enseignant de correction et de notation d'une copie étudiante ([Submission]).
/// Accessible depuis l'onglet « Copies » via la route nommée `EvaluationsRoutes.submissionGrade`.
class SubmissionGradeScreen extends StatefulWidget {
  final String submissionId;
  const SubmissionGradeScreen({super.key, required this.submissionId});

  @override
  State<SubmissionGradeScreen> createState() => _SubmissionGradeScreenState();
}

class _SubmissionGradeScreenState extends State<SubmissionGradeScreen> {
  final _controller = EvaluationsController.instance;

  /// Clé globale pilotant la validation de la note et du commentaire de retour.
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _grade;
  late final TextEditingController _feedback;

  @override
  void initState() {
    super.initState();
    // Préremplit la note et le feedback si la copie a déjà fait l'objet d'une évaluation.
    final sub = _controller.submissionById(widget.submissionId)!;
    _grade = TextEditingController(
      text: sub.grade?.toStringAsFixed(0) ?? '',
    );
    _feedback = TextEditingController(text: sub.feedback ?? '');
  }

  @override
  void dispose() {
    _grade.dispose();
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sub = _controller.submissionById(widget.submissionId)!;
    final assignment = _controller.assignmentById(sub.assignmentId)!;

    return Scaffold(
      backgroundColor: EduColors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Corriger la copie',
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
            // Récapitulatif de la copie : identité étudiant, indicateur de retard (`sub.isLate`), commentaire et fichiers.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: evalCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub.studentName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text('${assignment.title} · ${assignment.courseTitle}'),
                  const SizedBox(height: 8),
                  // Puce signalant visuellement si la copie a été déposée avant ou après l'échéance.
                  StatusChip(
                    label: sub.isLate ? 'Rendu en retard' : 'Rendu à temps',
                    color: sub.isLate ? EduColors.danger : EduColors.success,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Commentaire étudiant : ${sub.comment}',
                    style: const TextStyle(color: EduColors.textSecondary),
                  ),
                  ...sub.fileUrls.map(
                    (f) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.picture_as_pdf_rounded),
                      title: Text(f),
                      subtitle: const Text('Aperçu mock — MediaService L10'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Saisie décimale de la note bornée entre 0 et `assignment.maxGrade` (virgule ou point accepté).
            TextFormField(
              controller: _grade,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: evalInputDecoration(
                label: 'Note / ${assignment.maxGrade.toStringAsFixed(0)}',
                icon: Icons.grade_outlined,
              ),
              validator: (v) {
                final n = double.tryParse(v?.replaceAll(',', '.') ?? '');
                if (n == null) return 'Note numérique obligatoire.';
                if (n < 0 || n > assignment.maxGrade) {
                  return 'La note doit être entre 0 et ${assignment.maxGrade.toStringAsFixed(0)}.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            // Champ d'appréciation détaillée obligatoire destiné à l'étudiant.
            TextFormField(
              controller: _feedback,
              maxLines: 5,
              maxLength: 300,
              decoration: evalInputDecoration(
                label: 'Feedback',
                hint: 'Points forts, axes d\'amélioration…',
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.length < 10) return 'Feedback obligatoire (10 à 300 car.).';
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Enregistre la note dans le contrôleur, met à jour le carnet de notes et confirme via SnackBar.
            PrimaryCta(
              label: 'Publier la note',
              icon: Icons.check_circle_rounded,
              onPressed: () {
                if (!(_formKey.currentState?.validate() ?? false)) return;
                _controller.gradeSubmission(
                  submissionId: sub.id,
                  grade: double.parse(_grade.text.replaceAll(',', '.')),
                  feedback: _feedback.text.trim(),
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Note publiée. Notification FCM (L8) simulée.'),
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
