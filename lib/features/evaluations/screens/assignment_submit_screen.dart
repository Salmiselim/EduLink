import 'package:flutter/material.dart';
import '../data/evaluations_mock_data.dart';
import '../widgets/eval_ui.dart';

/// Écran étudiant permettant de déposer ou de mettre à jour un rendu pour un devoir donné.
/// Reçoit l'identifiant du devoir via `AssignmentSubmitArgs` depuis `EvaluationsRoutes.assignmentSubmit`.
class AssignmentSubmitScreen extends StatefulWidget {
  final String assignmentId;
  const AssignmentSubmitScreen({super.key, required this.assignmentId});

  @override
  State<AssignmentSubmitScreen> createState() => _AssignmentSubmitScreenState();
}

class _AssignmentSubmitScreenState extends State<AssignmentSubmitScreen> {
  /// Référence au singleton [EvaluationsController] pour lire le devoir et enregistrer la copie.
  final _controller = EvaluationsController.instance;

  /// Clé globale pilotant la validation synchrone du [Form] avant l'envoi du dépôt.
  final _formKey = GlobalKey<FormState>();
  final _comment = TextEditingController();

  /// Liste locale des noms de fichiers joints au rendu en cours d'édition.
  final List<String> _files = [];
  String? _fileError;

  @override
  void initState() {
    super.initState();
    // Préremplit le commentaire et les pièces jointes si l'étudiant modifie un dépôt déjà transmis.
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
    final assignment = _controller.assignmentById(widget.assignmentId)!;
    // Détecte si l'horloge courante a dépassé la date limite fixée sur le devoir.
    final late = DateTime.now().isAfter(assignment.dueDate);

    return Scaffold(
      backgroundColor: EduColors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Déposer le devoir',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: EduColors.text,
          ),
        ),
      ),
      // Formulaire réactif validant les champs au fil de la saisie de l'étudiant.
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Carte récapitulative présentant le sujet, les consignes et l'état d'échéance.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: evalCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assignment.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    assignment.courseTitle,
                    style: const TextStyle(color: EduColors.muted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    assignment.instructions,
                    style: const TextStyle(
                      height: 1.5,
                      color: EduColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Badge dynamique reflétant le dépassement d'échéance et la politique `allowLate`.
                  StatusChip(
                    label: late
                        ? (assignment.allowLate
                            ? 'En retard — dépôt encore possible'
                            : 'Échéance dépassée')
                        : 'À rendre avant ${formatDate(assignment.dueDate)}',
                    color: late ? EduColors.danger : EduColors.warning,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Bouton d'ajout simulé de pièce jointe alimentant la liste locale `_files`.
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _files.add('rendu_${_files.length + 1}.pdf');
                  _fileError = null;
                });
              },
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Ajouter un fichier (Cloudinary L10, simulé)'),
            ),
            if (_fileError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _fileError!,
                  style: const TextStyle(color: EduColors.danger),
                ),
              ),
            // Affichage sous forme de ListTile de chaque fichier joint avec suppression individuelle.
            ..._files.map(
              (f) => ListTile(
                leading: const Icon(Icons.insert_drive_file_rounded),
                title: Text(f),
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() => _files.remove(f)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Champ texte contrôlé exigeant un commentaire explicatif d'au moins 10 caractères.
            TextFormField(
              controller: _comment,
              maxLines: 4,
              maxLength: 300,
              decoration: evalInputDecoration(
                label: 'Commentaire pour l\'enseignant',
                hint: 'Précisez votre rendu…',
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.length < 10) return 'Commentaire obligatoire (10 à 300 car.).';
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Validation finale (fichiers, formulaire, autorisation de retard) puis enregistrement dans le contrôleur.
            PrimaryCta(
              label: 'Envoyer le dépôt',
              icon: Icons.send_rounded,
              onPressed: () {
                if (_files.isEmpty) {
                  setState(() => _fileError = 'Ajoutez au moins un fichier.');
                  return;
                }
                if (!(_formKey.currentState?.validate() ?? false)) return;
                // Bloque la remise si la date limite est dépassée et que `allowLate` vaut false.
                if (!_controller.canSubmitAssignment(assignment)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Les retards ne sont pas autorisés.')),
                  );
                  return;
                }
                _controller.submitAssignment(
                  assignmentId: assignment.id,
                  files: List.of(_files),
                  comment: _comment.text.trim(),
                );
                Navigator.pop(context);
                // Confirmation visuelle via SnackBar précisant si le dépôt a été marqué en retard.
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      late
                          ? 'Dépôt enregistré avec mention « en retard ».'
                          : 'Dépôt enregistré à temps.',
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
