import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../data/courses_mock_data.dart';
import '../models/courses_models.dart';
import '../services/courses_ai_service.dart';
import '../services/courses_document_service.dart';
import 'ai_tools.dart';
import 'courses_ui.dart';

// Feuille modale réutilisable de création et d'édition de chapitre (`ChapterEditSheet`).
// Partagée entre `CourseWizardScreen` et `CourseManageScreen` afin de factoriser
// le formulaire (`Form` + `GlobalKey<FormState>`), le choix du `ChapterType` et les
// validations spécifiques à chaque type de contenu.

/// Utilitaire statique ouvrant une `ModalBottomSheet` de saisie d'un chapitre.
class ChapterEditSheet {
  ChapterEditSheet._();

  /// Affiche la feuille modale d'ajout (`existing == null`) ou de modification (`existing != null`)
  /// d'un chapitre rattaché à [courseId], ajuste le retrait clavier via `viewInsets.bottom`
  /// et enregistre les données validées dans `CoursesController`.
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
                      // Sélecteur du format de support (`Wrap` de `ChoiceChip`), figé en mode édition.
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
                          if (v.trim().isEmpty) {
                            return 'Donnez un titre au chapitre.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      // Zone de saisie dynamique adaptée au `ChapterType` sélectionné.
                      _typeSpecificField(
                        type: type,
                        controller: contentController,
                        setSheetState: setSheetState,
                        sheetContext: sheetContext,
                        courseId: courseId,
                        titleController: titleController,
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

  /// Construit le champ de formulaire correspondant à [type] avec son `validator` dédié :
  /// texte long (avec outils IA : brouillon + orthographe), sélecteur de document PDF
  /// (copie locale dans l'app, visualisable et téléchargeable), URL YouTube ou URI HTTP/HTTPS externe.
  static Widget _typeSpecificField({
    required ChapterType type,
    required TextEditingController controller,
    required void Function(void Function()) setSheetState,
    required BuildContext sheetContext,
    required String courseId,
    required TextEditingController titleController,
  }) {
    switch (type) {
      case ChapterType.text:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: controller,
              maxLines: 6,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: courseInputDecoration(
                label: 'Contenu du chapitre',
                hint:
                    'Rédigez le contenu (séparez les paragraphes par une ligne vide)',
                icon: Icons.notes_rounded,
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.trim().isEmpty) {
                  return 'Rédigez le contenu du chapitre.';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            // Outils IA du module Cours : brouillon rédigé à partir du titre
            // du chapitre, et relecture orthographique titre + contenu.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AiToolButton(
                  'Brouillon IA',
                  compact: true,
                  onPressed: () => _draftContentWithAi(
                    sheetContext,
                    setSheetState,
                    courseId,
                    titleController,
                    controller,
                  ),
                ),
                AiToolButton(
                  "Vérifier l'orthographe",
                  compact: true,
                  onPressed: () => _checkSheetSpelling(
                    sheetContext,
                    type,
                    titleController,
                    controller,
                  ),
                ),
              ],
            ),
          ],
        );

      case ChapterType.pdf:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () => _pickChapterPdf(
                  sheetContext,
                  setSheetState,
                  courseId,
                  controller,
                ),
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

  /// Génère un brouillon de contenu via l'IA à partir du titre du chapitre
  /// et du contexte du cours (type « texte » uniquement).
  static Future<void> _draftContentWithAi(
    BuildContext sheetContext,
    void Function(void Function()) setSheetState,
    String courseId,
    TextEditingController titleController,
    TextEditingController contentController,
  ) async {
    final chapterTitle = titleController.text.trim();
    if (chapterTitle.isEmpty) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Text("Donnez d'abord un titre au chapitre."),
        ),
      );
      return;
    }
    final course = CoursesController.instance.courseById(courseId);
    final text = await runWithAiLoader<String>(
      sheetContext,
      "L'IA rédige un brouillon…",
      () => CoursesAiService.instance.draftChapterContent(
        courseTitle: course?.title ?? 'Cours',
        subject: course?.subject ?? 'Général',
        chapterTitle: chapterTitle,
      ),
    );
    if (text == null || !sheetContext.mounted) return;
    setSheetState(() => contentController.text = text);
  }

  /// Vérifie l'orthographe du titre (et du contenu pour un chapitre texte),
  /// puis propose les corrections dans une feuille d'application au choix.
  static Future<void> _checkSheetSpelling(
    BuildContext sheetContext,
    ChapterType type,
    TextEditingController titleController,
    TextEditingController contentController,
  ) async {
    final title = titleController.text.trim();
    final content =
        type == ChapterType.text ? contentController.text.trim() : '';
    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('Rien à vérifier : les champs sont vides.'),
        ),
      );
      return;
    }
    final corrections = await runWithAiLoader<List<AiFieldCorrection>>(
      sheetContext,
      "Vérification de l'orthographe…",
      () async {
        final results = <AiFieldCorrection>[];
        if (title.isNotEmpty) {
          results.add(
            AiFieldCorrection(
              label: 'Titre du chapitre',
              controller: titleController,
              corrected: await CoursesAiService.instance.correctSpelling(
                label: 'Titre du chapitre',
                text: title,
              ),
            ),
          );
        }
        if (content.isNotEmpty) {
          results.add(
            AiFieldCorrection(
              label: 'Contenu du chapitre',
              controller: contentController,
              corrected: await CoursesAiService.instance.correctSpelling(
                label: 'Contenu du chapitre',
                text: content,
              ),
            ),
          );
        }
        return results;
      },
    );
    if (corrections == null || !sheetContext.mounted) return;
    await showSpellingReviewSheet(sheetContext, corrections);
  }

  /// Ouvre un PDF (galerie / fichiers de l'appareil) et le copie dans le
  /// stockage local de l'application : l'étudiant pourra le visualiser dans
  /// l'app ou le télécharger. En cas d'échec, aucun chemin fictif n'est
  /// écrit et un message invite à réessayer.
  static Future<void> _pickChapterPdf(
    BuildContext sheetContext,
    void Function(void Function()) setSheetState,
    String courseId,
    TextEditingController contentController,
  ) async {
    String? pickedPath;
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      pickedPath = files.isEmpty ? null : files.first.path;
    } catch (error) {
      debugPrint('[ChapterEditSheet] Sélection impossible : $error');
    }
    if (pickedPath == null || !sheetContext.mounted) return;
    // Garde-fou avant copie : 20 Mo maximum.
    final file = File(pickedPath);
    if (file.lengthSync() > CoursesDocumentService.maxPdfBytes) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('PDF trop volumineux — 20 Mo maximum.'),
        ),
      );
      return;
    }
    final reference = await CoursesDocumentService.instance.importChapterPdf(
      courseId: courseId,
      file: file,
    );
    if (!sheetContext.mounted) return;
    if (reference != null) {
      setSheetState(() => contentController.text = reference);
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Text(
            'PDF ajouté depuis vos fichiers — les étudiants pourront le '
            'visualiser et le télécharger.',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(sheetContext).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 3),
        content: Text("Impossible d'importer ce PDF — réessayez."),
      ),
    );
  }
}
