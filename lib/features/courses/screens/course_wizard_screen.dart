import 'package:flutter/material.dart';
import '../data/courses_mock_data.dart';
import '../models/courses_models.dart';
import '../widgets/chapter_edit_sheet.dart';
import '../widgets/chapter_tile.dart';
import '../widgets/courses_ui.dart';

// Assistant séquentiel en quatre étapes de création ou de modification de cours
// (`CourseWizardScreen`), ouvert via `CoursesRoutes.courseWizard`.
// Guide l'enseignant à travers : 1. saisie et validation des métadonnées,
// 2. composition et réordonnancement des chapitres, 3. prévisualisation côté étudiant,
// 4. enregistrement en brouillon ou publication dans le catalogue.

/// Écran d'assistant multi-étapes gérant la création d'un nouveau cours ou l'édition de [existingCourse].
class CourseWizardScreen extends StatefulWidget {
  final Course? existingCourse;

  const CourseWizardScreen({super.key, this.existingCourse});

  @override
  State<CourseWizardScreen> createState() => _CourseWizardScreenState();
}

class _CourseWizardScreenState extends State<CourseWizardScreen> {
  final CoursesController _controller = CoursesController.instance;

  /// Clé globale rattachée au widget `Form` de l'étape 1 pour déclencher les `validator` avant avancement.
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  /// Libellés ordonnés des quatre jalons affichés dans le bandeau supérieur de progression.
  static const List<(int, String)> _stepLabels = [
    (1, 'Infos'),
    (2, 'Chapitres'),
    (3, 'Aperçu'),
    (4, 'Publication'),
  ];

  Course? _course;
  String? _subject;
  String? _level;
  int _step = 0;

  /// Indique si l'assistant a été ouvert à partir d'un cours existant plutôt qu'en création pure.
  bool get _isEditing => widget.existingCourse != null;

  @override
  void initState() {
    super.initState();
    _course = widget.existingCourse;
    if (_course != null) {
      _titleController.text = _course!.title;
      _descriptionController.text = _course!.description;
      _subject = _course!.subject;
      _level = _course!.level;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Récupère depuis `CoursesController` la liste ordonnée des chapitres du cours en cours d'édition.
  List<Chapter> get _chapters =>
      _course == null ? [] : _controller.chaptersOf(_course!.id);

  /// Persiste les champs du formulaire dans `CoursesController` : crée le brouillon initial
  /// lors du premier passage de l'étape 1, ou met à jour l'entité existante lors des passages suivants.
  void _commitCourseInfo() {
    if (_course == null) {
      _course = _controller.createCourse(
        title: _titleController.text.trim(),
        subject: _subject!,
        level: _level!,
        description: _descriptionController.text.trim(),
      );
    } else {
      _controller.updateCourse(
        _course!.id,
        title: _titleController.text.trim(),
        subject: _subject!,
        level: _level!,
        description: _descriptionController.text.trim(),
      );
    }
  }

  /// Valide le formulaire de l'étape 1 via `_formKey`, enregistre le cours puis passe à l'étape suivante.
  void _goNext() {
    if (_step == 0) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      _commitCourseInfo();
    }
    setState(() => _step += 1);
  }

  /// Finalise l'assistant à l'étape 4 : sauvegarde les métadonnées, publie éventuellement
  /// le cours via `CoursesController.setPublished` (si au moins un chapitre existe) et referme la route.
  void _finish({required bool publish}) {
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _step = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complétez les informations du cours (étape 1).'),
        ),
      );
      return;
    }
    _commitCourseInfo();
    if (publish) {
      final ok = _controller.setPublished(_course!.id, true);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ajoutez au moins un chapitre pour publier le cours.',
            ),
          ),
        );
        return;
      }
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(
          publish
              ? 'Cours « ${_course!.title} » publié dans le catalogue !'
              : 'Cours enregistré en brouillon.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CourseColors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEditing ? 'Modifier le cours' : 'Assistant · Nouveau cours',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: CourseColors.text,
          ),
        ),
      ),
      body: Column(
        children: [
          // Bandeau supérieur d'avancement : `LinearProgressIndicator` proportionnel à l'étape courante
          // suivi des pastilles numérotées reliées par des `Divider` extensibles (`Expanded`).
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / _stepLabels.length,
                    minHeight: 4,
                    backgroundColor: CourseColors.neutralBg,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      CourseColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var i = 0; i < _stepLabels.length; i++) ...[
                      if (i > 0)
                        const Expanded(
                          child: Divider(color: CourseColors.border),
                        ),
                      _stepChip(i),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildStep(),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: CourseColors.border)),
          ),
          child: Row(
            children: [
              if (_step > 0)
                OutlinedButton(
                  onPressed: () => setState(() => _step -= 1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CourseColors.textSecondary,
                    side: const BorderSide(color: CourseColors.border),
                    minimumSize: const Size(90, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Retour',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              const Spacer(),
              if (_step < 3)
                SizedBox(
                  height: 46,
                  child: FilledButton(
                    onPressed: _goNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: CourseColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Continuer',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
              else ...[
                SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => _finish(publish: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CourseColors.warning,
                      side: const BorderSide(color: CourseColors.warning),
                      minimumSize: const Size(0, 46),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Brouillon',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 46,
                  child: FilledButton(
                    onPressed: () => _finish(publish: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: CourseColors.success,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Publier le cours',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Construit la pastille visuelle d'une étape (coche verte si validée, primaire si active, neutre sinon).
  Widget _stepChip(int index) {
    final active = index == _step;
    final done = index < _step;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done
                ? CourseColors.success
                : (active ? CourseColors.primary : CourseColors.neutralBg),
            shape: BoxShape.circle,
          ),
          child: done
              ? const Icon(Icons.check_rounded,
                  size: 13, color: Colors.white)
              : Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: active
                        ? Colors.white
                        : CourseColors.muted,
                  ),
                ),
        ),
        const SizedBox(width: 5),
        Text(
          _stepLabels[index].$2,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? CourseColors.text : CourseColors.muted,
          ),
        ),
      ],
    );
  }

  /// Retourne le sous-arbre correspondant à l'indice d'étape courant `_step`.
  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildInfosStep();
      case 1:
        return _buildChaptersStep();
      case 2:
        return _buildPreviewStep();
      default:
        return _buildPublishStep();
    }
  }

  // Étape 1 : formulaire de saisie des métadonnées générales du cours.

  /// Construit le `Form` contrôlé par `_formKey` regroupant les `TextFormField` (titre, description)
  /// et les `DropdownButtonFormField` (matière, niveau) munis de leurs fonctions `validator`.
  Widget _buildInfosStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informations du cours',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: CourseColors.text,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ces informations apparaissent dans le catalogue public.',
              style: TextStyle(fontSize: 11.5, color: CourseColors.muted),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _titleController,
              maxLength: 80,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: courseInputDecoration(
                label: 'Titre du cours',
                hint: 'Ex. Algorithmique & Structures de Données',
                icon: Icons.title_rounded,
                counterText: '',
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.length < 5 || v.length > 80) {
                  return 'Le titre doit contenir entre 5 et 80 caractères.';
                }
                if (double.tryParse(v) != null) {
                  return 'Le titre ne peut pas être un nombre.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _subject,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: courseInputDecoration(
                label: 'Matière',
                icon: Icons.sell_outlined,
              ),
              items: CoursesController.subjects
                  .map(
                    (subject) => DropdownMenuItem(
                      value: subject,
                      child: Text(
                        subject,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _subject = value),
              validator: (value) =>
                  value == null ? 'Choisissez une matière.' : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _level,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: courseInputDecoration(
                label: 'Niveau',
                icon: Icons.school_outlined,
              ),
              items: CoursesController.levels
                  .map(
                    (level) => DropdownMenuItem(
                      value: level,
                      child: Text(
                        level,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _level = value),
              validator: (value) =>
                  value == null ? 'Choisissez un niveau.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              maxLength: 600,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: courseInputDecoration(
                label: 'Description',
                hint: 'Présentez le contenu et les objectifs du cours',
                icon: Icons.description_outlined,
                counterText: '',
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.length < 20 || v.length > 600) {
                  return 'La description doit contenir entre 20 et 600 '
                      'caractères.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () {
                  // Point d'entrée réservé au téléversement distant de l'image de couverture.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      duration: Duration(seconds: 2),
                      content: Text(
                        'Image de couverture via le service média '
                        '(Cloudinary) — intégration à venir.',
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: CourseColors.primary,
                  side: const BorderSide(color: CourseColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.image_outlined, size: 18),
                label: const Text(
                  'Ajouter une image de couverture',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Étape 2 : création, édition et réordonnancement des chapitres du cours.

  /// Affiche la séquence des chapitres dans un `ReorderableListView.builder` relié à
  /// `CoursesController.reorderChapters`, ainsi que le bouton d'ouverture de `ChapterEditSheet`.
  Widget _buildChaptersStep() {
    final chapters = _chapters;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Chapitres du cours',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: CourseColors.text,
                ),
              ),
            ),
            Text(
              '${chapters.length} chapitre${chapters.length > 1 ? 's' : ''} · '
              '${_course == null ? 0 : _controller.totalDurationMin(_course!.id)} min',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: CourseColors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Glissez la poignée pour réordonner ; touchez un chapitre pour le '
          'modifier.',
          style: TextStyle(fontSize: 11.5, color: CourseColors.muted),
        ),
        const SizedBox(height: 12),
        if (chapters.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: courseCardDecoration(),
            child: const Text(
              "Aucun chapitre pour l'instant. Ajoutez du contenu de quatre "
              'types : texte rédigé, PDF, vidéo YouTube ou lien externe.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: CourseColors.muted,
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: chapters.length,
            onReorderItem: (oldIndex, newIndex) {
              if (_course != null) {
                _controller.reorderChapters(_course!.id, oldIndex, newIndex);
              }
            },
            itemBuilder: (context, i) {
              final chapter = chapters[i];
              return Padding(
                key: ValueKey(chapter.id),
                padding: const EdgeInsets.only(bottom: 8),
                child: ChapterTile(
                  chapter: chapter,
                  number: i + 1,
                  onTap: () => ChapterEditSheet.open(
                    context,
                    courseId: _course!.id,
                    existing: chapter,
                  ),
                  trailingOverride: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: const Icon(
                          Icons.drag_indicator_rounded,
                          color: CourseColors.muted,
                          size: 20,
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _openChapterActionsSheet(chapter),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.more_vert_rounded,
                            color: CourseColors.muted,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: _course == null
                ? null
                : () => ChapterEditSheet.open(
                      context,
                      courseId: _course!.id,
                    ),
            style: OutlinedButton.styleFrom(
              foregroundColor: CourseColors.primary,
              side: const BorderSide(color: CourseColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text(
              'Ajouter un chapitre',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  /// Ouvre une `ModalBottomSheet` proposant la modification ou la suppression d'un chapitre.
  void _openChapterActionsSheet(Chapter chapter) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
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
                Text(
                  chapter.title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: CourseColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.edit_rounded,
                    color: CourseColors.primary,
                  ),
                  title: const Text('Modifier le chapitre'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ChapterEditSheet.open(
                      context,
                      courseId: _course!.id,
                      existing: chapter,
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.delete_rounded,
                    color: CourseColors.danger,
                  ),
                  title: const Text(
                    'Supprimer le chapitre',
                    style: TextStyle(color: CourseColors.danger),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _controller.deleteChapter(_course!.id, chapter.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        duration: Duration(seconds: 2),
                        content: Text('Chapitre supprimé.'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Étape 3 : prévisualisation fidèle du rendu de la fiche cours côté étudiant.

  /// Reproduit la carte d'en-tête, les badges (`Wrap`) et le sommaire tels qu'affichés dans le catalogue.
  Widget _buildPreviewStep() {
    final course = _course!;
    final chapters = _chapters;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Aperçu — ce que verra l\'étudiant',
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            color: CourseColors.text,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: courseCardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 110,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [CourseColors.primary, CourseColors.primaryDark],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 44,
                    color: Colors.white24,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleController.text.trim(),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                        color: CourseColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_controller.currentUserName} · ${course.teacherVerified ? 'Enseignant vérifié' : 'Enseignant'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: CourseColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        SubjectBadge(subject: _subject!),
                        LevelBadge(level: _level!),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _descriptionController.text.trim(),
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: CourseColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SectionHeader(title: 'Chapitres', count: chapters.length),
                    ...chapters.map(
                      (chapter) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ChapterTile(
                          chapter: chapter,
                          number: chapters.indexOf(chapter) + 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Étape 4 : récapitulatif final avant enregistrement en brouillon ou publication publique.

  /// Résume les caractéristiques du cours via des lignes `InfoRow` avant le choix final de visibilité.
  Widget _buildPublishStep() {
    final course = _course!;
    final chapters = _chapters;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Publication',
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            color: CourseColors.text,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: courseCardDecoration(),
          child: Column(
            children: [
              InfoRow(
                icon: Icons.title_rounded,
                label: 'Titre',
                value: _titleController.text.trim(),
              ),
              InfoRow(
                icon: Icons.sell_outlined,
                label: 'Matière',
                value: _subject!,
              ),
              InfoRow(
                icon: Icons.school_outlined,
                label: 'Niveau',
                value: _level!,
              ),
              InfoRow(
                icon: Icons.format_list_numbered_rounded,
                label: 'Chapitres',
                value:
                    '${chapters.length} · ${_controller.totalDurationMin(course.id)} min',
              ),
              InfoRow(
                icon: Icons.visibility_outlined,
                label: 'Visibilité actuelle',
                value: course.isPublished ? 'Publié' : 'Brouillon',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CourseColors.infoBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: CourseColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '« Publier le cours » le rend visible dans le catalogue '
                  "public ; les étudiants pourront s'y inscrire. "
                  '« Brouillon » garde le cours visible uniquement dans '
                  "l'onglet « Mes cours ».",
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: CourseColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
