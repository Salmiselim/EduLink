import 'package:flutter/material.dart';
import '../data/courses_mock_data.dart';
import '../models/courses_models.dart';
import 'courses_ui.dart';

// ============================================================================
// FEUILLE COULISSANTE D'AJOUT / MODIFICATION DE CHAPITRE
// Partagée entre l'assistant de création de cours (CourseWizardScreen) et le
// tableau de gestion (CourseManageScreen). Choisit le type (texte, PDF, vidéo
// ou lien), valide les champs selon le type, puis écrit via le contrôleur.
// ============================================================================

class ChapterEditSheet {
  ChapterEditSheet._();

  /// Ouvre la feuille. `existing` = chapitre à modifier (sinon ajout).
  static Future<void> open(
    BuildContext context, {
    required String courseId,
    Chapter? existing,
  }) async {
    final controller = CoursesController.instance;
    final isEditing = existing != null;
    final formKey = GlobalKey<FormState>();

    ChapterType type = existing?.type ?? ChapterType.text;
    final titleController = TextEditingController(text: existing?.title ?? '');
    final contentController =
        TextEditingController(text: existing?.content ?? '');
    final durationController = TextEditingController(
      text: existing == null ? '' : '${existing.durationMin}',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: CourseColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: type.background,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              type.icon,
                              color: type.color,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isEditing
                                ? 'Modifier le chapitre'
                                : 'Nouveau chapitre',
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: CourseColors.text,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Type de contenu (verrouillé en modification)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final t in ChapterType.values)
                            ChoiceChip(
                              label: Text(t.label),
                              selected: type == t,
                              selectedColor: CourseColors.primary,
                              labelStyle: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: type == t
                                    ? Colors.white
                                    : CourseColors.textSecondary,
                              ),
                              showCheckmark: false,
                              onSelected: isEditing
                                  ? null
                                  : (selected) =>
                                      setSheetState(() => type = t),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: titleController,
                        maxLength: 60,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: courseInputDecoration(
                          label: 'Titre du chapitre',
                          hint: 'Ex. Les arbres binaires de recherche',
                          icon: Icons.title_rounded,
                          counterText: '',
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.length < 3 || v.length > 60) {
                            return 'Entre 3 et 60 caractères.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      // Champ spécifique au type de contenu
                      _typeSpecificField(
                        type: type,
                        controller: contentController,
                        setSheetState: setSheetState,
                        sheetContext: sheetContext,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: durationController,
                        keyboardType: TextInputType.number,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: courseInputDecoration(
                          label: 'Durée estimée (minutes)',
                          hint: 'Ex. 45',
                          icon: Icons.schedule_rounded,
                        ),
                        validator: (value) {
                          final minutes = int.tryParse(value?.trim() ?? '');
                          if (minutes == null ||
                              minutes < 5 ||
                              minutes > 240) {
                            return 'Durée entre 5 et 240 minutes.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: () {
                            if (!(formKey.currentState?.validate() ??
                                false)) {
                              return;
                            }
                            final title = titleController.text.trim();
                            final content = contentController.text.trim();
                            final duration =
                                int.parse(durationController.text.trim());

                            if (isEditing) {
                              controller.updateChapter(
                                courseId,
                                existing.id,
                                title: title,
                                durationMin: duration,
                                content: content,
                              );
                            } else {
                              controller.addChapter(
                                courseId,
                                title: title,
                                type: type,
                                content: content,
                                durationMin: duration,
                              );
                            }
                            Navigator.pop(sheetContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                duration: const Duration(seconds: 2),
                                content: Text(
                                  isEditing
                                      ? 'Chapitre mis à jour.'
                                      : 'Chapitre « $title » ajouté.',
                                ),
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: CourseColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            isEditing
                                ? 'Enregistrer les modifications'
                                : 'Ajouter le chapitre',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Champ de contenu selon le type choisi
  static Widget _typeSpecificField({
    required ChapterType type,
    required TextEditingController controller,
    required void Function(void Function()) setSheetState,
    required BuildContext sheetContext,
  }) {
    switch (type) {
      case ChapterType.text:
        return TextFormField(
          controller: controller,
          maxLines: 6,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: courseInputDecoration(
            label: 'Contenu du chapitre',
            hint: 'Rédigez le contenu (séparez les paragraphes par une ligne vide)',
            icon: Icons.notes_rounded,
          ),
          validator: (value) {
            final v = value?.trim() ?? '';
            if (v.length < 20) {
              return 'Le contenu doit contenir au moins 20 caractères.';
            }
            return null;
          },
        );

      case ChapterType.pdf:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () {
                  // Upload Cloudinary via le service média partagé
                  setSheetState(() {
                    controller.text =
                        'cloudinary://edulink/chapters/chapitre_${DateTime.now().millisecondsSinceEpoch}.pdf';
                  });
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(
                      duration: Duration(seconds: 2),
                      content: Text(
                        'Fichier simulé — upload via le service média '
                        '(Cloudinary) — intégration à venir.',
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: CourseColors.primary,
                  side: const BorderSide(color: CourseColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text(
                  'Choisir un fichier PDF',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (controller.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: CourseColors.neutralBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  controller.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: CourseColors.muted,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        );

      case ChapterType.video:
        return TextFormField(
          controller: controller,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          keyboardType: TextInputType.url,
          decoration: courseInputDecoration(
            label: 'URL de la vidéo YouTube',
            hint: 'https://www.youtube.com/watch?v=...',
            icon: Icons.smart_display_rounded,
          ),
          validator: (value) {
            final v = value?.trim() ?? '';
            if (!v.contains('youtube.com') && !v.contains('youtu.be')) {
              return 'Entrez une URL YouTube valide.';
            }
            return null;
          },
        );

      case ChapterType.link:
        return TextFormField(
          controller: controller,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          keyboardType: TextInputType.url,
          decoration: courseInputDecoration(
            label: 'URL de la ressource externe',
            hint: 'https://...',
            icon: Icons.link_rounded,
          ),
          validator: (value) {
            final v = value?.trim() ?? '';
            final uri = Uri.tryParse(v);
            if (uri == null ||
                !uri.hasScheme ||
                (uri.scheme != 'http' && uri.scheme != 'https')) {
              return 'Entrez une URL valide (http/https).';
            }
            return null;
          },
        );
    }
  }
}
