import 'package:flutter/material.dart';
import '../data/evaluations_mock_data.dart';
import '../routes/evaluations_routes.dart';
import '../widgets/eval_ui.dart';

/// Écran de consultation détaillée d'un support pédagogique ([CourseDocument]).
/// Permet le téléchargement avec incrémentation du compteur et, pour l'enseignant, l'accès à l'édition.
class DocumentDetailScreen extends StatelessWidget {
  final String documentId;
  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  Widget build(BuildContext context) {
    final controller = EvaluationsController.instance;
    // Écoute le contrôleur via ListenableBuilder pour rafraîchir immédiatement la fiche
    // après un téléchargement (`downloadsCount + 1`) ou une modification dans DocumentWizardScreen.
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final doc = controller.documentById(documentId);
        if (doc == null) {
          return const Scaffold(
            body: Center(child: Text('Document introuvable')),
          );
        }
        return Scaffold(
          backgroundColor: EduColors.scaffold,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Text(
              'Document du cours',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: EduColors.text,
              ),
            ),
            actions: [
              // Action d'édition visible uniquement lorsque le rôle actif est enseignant.
              if (controller.isTeacher)
                IconButton(
                  tooltip: 'Modifier',
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      EvaluationsRoutes.documentWizard,
                      arguments: DocumentWizardArgs(existing: doc),
                    );
                  },
                  icon: const Icon(Icons.edit_rounded),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Carte présentant le dossier thématique, le titre, la description et les statistiques du fichier.
              Container(
                padding: const EdgeInsets.all(16),
                decoration: evalCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusChip(
                      label: doc.folder.label,
                      color: doc.folder.color,
                      icon: doc.folder.icon,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      doc.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${doc.courseTitle} · ${doc.teacherName}',
                      style: const TextStyle(color: EduColors.muted),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      doc.description,
                      style: const TextStyle(
                        height: 1.5,
                        color: EduColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Fichier : ${doc.fileUrl}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                      ),
                    ),
                    Text(
                      '${doc.downloadsCount} téléchargement(s)',
                      style: const TextStyle(color: EduColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Bouton d'action incrémentant le compteur du document dans le contrôleur et affichant un SnackBar.
              PrimaryCta(
                label: 'Télécharger (simulé)',
                icon: Icons.download_rounded,
                onPressed: () {
                  controller.incrementDownload(doc.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${doc.fileUrl} téléchargé (compteur +1).'),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
