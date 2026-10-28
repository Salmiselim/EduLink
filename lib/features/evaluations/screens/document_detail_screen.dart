import 'package:flutter/material.dart';
import '../data/evaluations_mock_data.dart';
import '../routes/evaluations_routes.dart';
import '../widgets/eval_ui.dart';

class DocumentDetailScreen extends StatelessWidget {
  final String documentId;
  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  Widget build(BuildContext context) {
    final controller = EvaluationsController.instance;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final doc = controller.documentById(documentId);
        if (doc == null) {
          return const Scaffold(
            body: Center(child: Text('Document introuvable.')),
          );
        }
        return Scaffold(
          backgroundColor: EduColors.scaffold,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Text(
              'Document de cours',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: EduColors.text,
              ),
            ),
            actions: [
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
              Container(
                padding: const EdgeInsets.all(18),
                decoration: evalCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusChip(
                          label: doc.folder.label,
                          color: doc.folder.color,
                          icon: doc.folder.icon,
                        ),
                        const SizedBox(width: 8),
                        StatusChip(
                          label: doc.courseTitle,
                          color: EduColors.muted,
                          background: EduColors.neutralBg,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      doc.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: EduColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Publié par ${doc.teacherName}',
                      style: const TextStyle(color: EduColors.muted, fontSize: 13),
                    ),
                    const Divider(height: 24),
                    const Text(
                      'Description :',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doc.description,
                      style: const TextStyle(
                        height: 1.5,
                        fontSize: 13.5,
                        color: EduColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: EduColors.neutralBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf_rounded, color: doc.folder.color, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc.fileUrl,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${doc.downloadsCount} téléchargement(s)',
                                  style: const TextStyle(fontSize: 11.5, color: EduColors.muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              PrimaryCta(
                label: 'Télécharger le document (${doc.downloadsCount} téléchargements)',
                icon: Icons.download_rounded,
                backgroundColor: doc.folder.color,
                onPressed: () {
                  controller.incrementDownload(doc.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: EduColors.success,
                      content: Text('${doc.fileUrl} téléchargé avec succès (compteur mis à jour).'),
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
