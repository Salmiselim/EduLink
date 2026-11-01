import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/evaluations_mock_data.dart';
import '../models/evaluations_models.dart';
import '../routes/evaluations_routes.dart';
import '../widgets/eval_ui.dart';

/// Écran principal du module Évaluations adaptant dynamiquement ses onglets et ses actions
/// selon le rôle courant (`UserRole.student` ou `UserRole.teacher`) exposé par [EvaluationsController].
class EvaluationsScreen extends StatefulWidget {
  const EvaluationsScreen({super.key});

  @override
  State<EvaluationsScreen> createState() => _EvaluationsScreenState();
}

class _EvaluationsScreenState extends State<EvaluationsScreen> {
  /// Instance singleton du contrôleur réactif fournissant les données et actions métier.
  final _controller = EvaluationsController.instance;

  /// Contrôleur du champ de recherche filtrant les quiz et les devoirs par titre ou par cours.
  final _search = TextEditingController();

  /// Indice de la sous-section active sélectionnée dans le [SegmentedButton] (`0`, `1` ou `2`).
  int _section = 0;

  /// Filtre par nature d'évaluation (`all`, `quiz` ou `assignment`) piloté par des [ChoiceChip].
  String _typeFilter = 'all';

  /// Identifiant du cours sélectionné pour filtrer le carnet de notes ou l'espace documentaire (`null` = tous).
  String? _courseFilter;

  /// Répertoire thématique sélectionné pour filtrer les supports de cours (`null` = tous les dossiers).
  DocumentFolder? _folderFilter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reconstruit automatiquement les onglets et listes dès que `notifyListeners()` est appelé
    // sur le contrôleur (changement de rôle, publication, remise de copie, notation ou téléchargement).
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final teacher = _controller.isTeacher;
        return Column(
          children: [
            // Sélecteur segmenté à 3 vues : Mes évaluations / Copies / Documents côté enseignant,
            // ou À faire / Notes / Documents côté étudiant.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SegmentedButton<int>(
                segments: teacher
                    ? const [
                        ButtonSegment(
                          value: 0,
                          label: Text('Mes évaluations'),
                          icon: Icon(Icons.library_books_outlined),
                        ),
                        ButtonSegment(
                          value: 1,
                          label: Text('Copies'),
                          icon: Icon(Icons.rate_review_outlined),
                        ),
                        ButtonSegment(
                          value: 2,
                          label: Text('Documents'),
                          icon: Icon(Icons.folder_outlined),
                        ),
                      ]
                    : const [
                        ButtonSegment(
                          value: 0,
                          label: Text('À faire'),
                          icon: Icon(Icons.flag_outlined),
                        ),
                        ButtonSegment(
                          value: 1,
                          label: Text('Notes'),
                          icon: Icon(Icons.insights_outlined),
                        ),
                        ButtonSegment(
                          value: 2,
                          label: Text('Documents'),
                          icon: Icon(Icons.folder_outlined),
                        ),
                      ],
                selected: {_section},
                onSelectionChanged: (s) => setState(() => _section = s.first),
              ),
            ),
            // Zone principale extensible affichant la vue associée au rôle et au segment actif.
            Expanded(
              child: teacher
                  ? (_section == 0
                      ? _teacherEvaluations()
                      : _section == 1
                          ? _teacherCopies()
                          : _documents())
                  : (_section == 0
                      ? _studentTodo()
                      : _section == 1
                          ? _gradebook(studentOnly: true)
                          : _documents()),
            ),
          ],
        );
      },
    );
  }

  /// Champ de recherche textuelle déclenchant un filtrage immédiat des cartes à chaque frappe.
  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        decoration: evalInputDecoration(
          label: 'Rechercher',
          hint: 'Titre, cours…',
          icon: Icons.search_rounded,
        ),
      ),
    );
  }

  /// Vue étudiante « À faire » regroupant les quiz publiés et les devoirs des cours inscrits,
  /// filtrés par mot-clé et par catégorie (`ChoiceChip`).
  Widget _studentTodo() {
    final q = _search.text.trim().toLowerCase();
    final quizzes = _controller.publishedQuizzesForStudent().where((item) {
      if (_typeFilter == 'assignment') return false;
      return q.isEmpty ||
          item.title.toLowerCase().contains(q) ||
          item.courseTitle.toLowerCase().contains(q);
    });
    final assignments = _controller.assignmentsForStudent().where((item) {
      if (_typeFilter == 'quiz') return false;
      return q.isEmpty ||
          item.title.toLowerCase().contains(q) ||
          item.courseTitle.toLowerCase().contains(q);
    });

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _searchBar(),
        // Barre de filtres rapides par type d'évaluation disposée dans un Wrap adaptatif.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Tout'),
                selected: _typeFilter == 'all',
                onSelected: (_) => setState(() => _typeFilter = 'all'),
              ),
              ChoiceChip(
                label: const Text('Quiz'),
                selected: _typeFilter == 'quiz',
                onSelected: (_) => setState(() => _typeFilter = 'quiz'),
              ),
              ChoiceChip(
                label: const Text('Devoirs'),
                selected: _typeFilter == 'assignment',
                onSelected: (_) => setState(() => _typeFilter = 'assignment'),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SectionHeader(
            title: 'Évaluations à venir',
            subtitle: 'GET /evaluations/upcoming',
          ),
        ),
        if (quizzes.isEmpty && assignments.isEmpty)
          const EmptyState(
            icon: Icons.event_available_rounded,
            title: 'Rien à faire',
            subtitle: 'Les quiz et devoirs de vos cours inscrits apparaîtront ici.',
          ),
        ...quizzes.map(_quizTile),
        ...assignments.map(_assignmentTile),
      ],
    );
  }

  /// Carte étudiante d'un [Quiz] affichant le quota de tentatives, le dernier score éventuel
  /// et les boutons de navigation vers `QuizTakeScreen` ou `QuizResultsScreen`.
  Widget _quizTile(Quiz quiz) {
    final count = _controller.attemptCountFor(quiz.id, _controller.currentUserId);
    final last = _controller.attemptsForQuiz(
      quiz.id,
      student: _controller.currentUserId,
    ).where((a) => a.isSubmitted);
    final canTake = _controller.canTakeQuiz(quiz) && !_controller.isTeacher;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (last.isNotEmpty) {
            Navigator.pushNamed(
              context,
              EvaluationsRoutes.quizResults,
              arguments: QuizResultsArgs(
                quizId: quiz.id,
                attemptId: last.first.id,
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: evalCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusChip(
                    label: 'Quiz',
                    color: EduColors.primary,
                    icon: Icons.quiz_rounded,
                  ),
                  const SizedBox(width: 6),
                  StatusChip(
                    label: quiz.courseTitle,
                    color: EduColors.muted,
                    background: EduColors.neutralBg,
                  ),
                  const Spacer(),
                  if (last.isNotEmpty)
                    Text(
                      '${EvaluationsController.formatScore(last.first.score ?? 0)} / 20',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                quiz.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Échéance ${formatDate(quiz.dueDate)} · $count/${quiz.attemptsAllowed} tentative(s)',
                style: const TextStyle(fontSize: 12.5, color: EduColors.muted),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (canTake)
                    FilledButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          EvaluationsRoutes.quizTake,
                          arguments: QuizTakeArgs(quizId: quiz.id),
                        );
                      },
                      child: const Text('Passer le quiz'),
                    ),
                  if (!canTake && last.isEmpty)
                    const Text(
                      'Indisponible (dates ou tentatives)',
                      style: TextStyle(color: EduColors.muted, fontSize: 12.5),
                    ),
                  if (last.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          EvaluationsRoutes.quizResults,
                          arguments: QuizResultsArgs(
                            quizId: quiz.id,
                            attemptId: last.first.id,
                          ),
                        );
                      },
                      child: const Text('Voir le résultat'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Carte étudiante d'un [Assignment] indiquant l'échéance, la mention éventuelle de retard (`sub.isLate`),
  /// la note obtenue et le bouton d'accès à `AssignmentSubmitScreen` (désactivé si hors délai non toléré).
  Widget _assignmentTile(Assignment assignment) {
    final sub = _controller.submissionFor(
      assignment.id,
      _controller.currentUserId,
    );
    final canSubmit = _controller.canSubmitAssignment(assignment);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: evalCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const StatusChip(
                  label: 'Devoir',
                  color: EduColors.warning,
                  icon: Icons.assignment_rounded,
                ),
                const SizedBox(width: 6),
                StatusChip(
                  label: assignment.courseTitle,
                  color: EduColors.muted,
                  background: EduColors.neutralBg,
                ),
                const Spacer(),
                if (sub?.grade != null)
                  Text(
                    formatGrade(sub!.grade, assignment.maxGrade),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              assignment.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              'Échéance ${formatDate(assignment.dueDate)}'
              '${sub == null ? '' : (sub.isLate ? ' · En retard' : ' · Déposé')}',
              style: const TextStyle(fontSize: 12.5, color: EduColors.muted),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: canSubmit
                  ? () {
                      Navigator.pushNamed(
                        context,
                        EvaluationsRoutes.assignmentSubmit,
                        arguments: AssignmentSubmitArgs(
                          assignmentId: assignment.id,
                        ),
                      );
                    }
                  : null,
              child: Text(sub == null ? 'Déposer' : 'Modifier le dépôt'),
            ),
          ],
        ),
      ),
    );
  }

  /// Vue enseignante « Mes évaluations » permettant de filtrer, modifier, publier/masquer,
  /// consulter les statistiques ou supprimer avec confirmation les quiz et les devoirs.
  Widget _teacherEvaluations() {
    final q = _search.text.trim().toLowerCase();
    final quizzes = _controller.quizzes.where((item) {
      if (_typeFilter == 'assignment') return false;
      return q.isEmpty || item.title.toLowerCase().contains(q);
    });
    final assignments = _controller.assignments.where((item) {
      if (_typeFilter == 'quiz') return false;
      return q.isEmpty || item.title.toLowerCase().contains(q);
    });
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        _searchBar(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Tout'),
                selected: _typeFilter == 'all',
                onSelected: (_) => setState(() => _typeFilter = 'all'),
              ),
              ChoiceChip(
                label: const Text('Quiz'),
                selected: _typeFilter == 'quiz',
                onSelected: (_) => setState(() => _typeFilter = 'quiz'),
              ),
              ChoiceChip(
                label: const Text('Devoirs'),
                selected: _typeFilter == 'assignment',
                onSelected: (_) => setState(() => _typeFilter = 'assignment'),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SectionHeader(
            title: 'Quiz et dépôts',
            subtitle: 'CRUD enseignant · publier · statistiques',
          ),
        ),
        // Cartes de gestion enseignant pour chaque quiz (brouillon ou publié).
        ...quizzes.map((quiz) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: evalCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StatusChip(
                        label: quiz.isPublished ? 'Publié' : 'Brouillon',
                        color: quiz.isPublished
                            ? EduColors.success
                            : EduColors.muted,
                      ),
                      const SizedBox(width: 6),
                      StatusChip(
                        label: quiz.courseTitle,
                        color: EduColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    quiz.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${quiz.questions.length} questions · ${quiz.timeLimitMin} min',
                    style: const TextStyle(color: EduColors.muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 8),
                  // Barre d'actions enveloppée dans un Wrap pour éviter tout débordement horizontal sur petit écran.
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            EvaluationsRoutes.quizWizard,
                            arguments: QuizWizardArgs(existing: quiz),
                          );
                        },
                        child: const Text('Modifier'),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            EvaluationsRoutes.quizResults,
                            arguments: QuizResultsArgs(quizId: quiz.id),
                          );
                        },
                        child: const Text('Résultats'),
                      ),
                      FilledButton(
                        onPressed: () =>
                            _controller.publishQuiz(quiz.id, !quiz.isPublished),
                        child: Text(quiz.isPublished ? 'Masquer' : 'Publier'),
                      ),
                      IconButton(
                        tooltip: 'Supprimer',
                        onPressed: () => _confirmDelete(
                          'Supprimer ce quiz ?',
                          () => _controller.deleteQuiz(quiz.id),
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: EduColors.danger,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        // Cartes de gestion enseignant pour chaque devoir avec compteur de copies en attente.
        ...assignments.map((asg) {
          final pending = _controller.submissions
              .where(
                (s) =>
                    s.assignmentId == asg.id &&
                    s.status == SubmissionStatus.submitted,
              )
              .length;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: evalCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const StatusChip(
                        label: 'Devoir',
                        color: EduColors.warning,
                      ),
                      const SizedBox(width: 6),
                      if (pending > 0)
                        StatusChip(
                          label: '$pending copie(s) à corriger',
                          color: EduColors.danger,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    asg.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${asg.courseTitle} · max ${asg.maxGrade.toStringAsFixed(0)}',
                    style: const TextStyle(color: EduColors.muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            EvaluationsRoutes.assignmentWizard,
                            arguments: AssignmentWizardArgs(existing: asg),
                          );
                        },
                        child: const Text('Modifier'),
                      ),
                      IconButton(
                        onPressed: () => _confirmDelete(
                          'Supprimer ce devoir ?',
                          () => _controller.deleteAssignment(asg.id),
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: EduColors.danger,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// Vue enseignante « Copies » combinant la file d'attente des dépôts à noter
  /// (ouvrant `SubmissionGradeScreen`) et le carnet de notes complet de la promotion.
  Widget _teacherCopies() {
    final copies = _controller.copiesToGrade();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(
          title: 'Copies à corriger',
          subtitle: 'PATCH /submissions/:id/grade',
        ),
        if (copies.isEmpty)
          const EmptyState(
            icon: Icons.task_alt_rounded,
            title: 'Aucune copie en attente',
            subtitle: 'Les dépôts étudiants apparaîtront ici.',
          ),
        ...copies.map((sub) {
          final asg = _controller.assignmentById(sub.assignmentId);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: evalCardDecoration(),
            child: ListTile(
              title: Text(
                sub.studentName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${asg?.title ?? ''} · ${formatDate(sub.submittedAt)}'
                '${sub.isLate ? ' · retard' : ''}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  EvaluationsRoutes.submissionGrade,
                  arguments: SubmissionGradeArgs(submissionId: sub.id),
                );
              },
            ),
          );
        }),
        const SizedBox(height: 16),
        _gradebook(studentOnly: false),
      ],
    );
  }

  /// Composant partagé du carnet de notes : affiche uniquement les notes de l'étudiant connecté
  /// lorsque [studentOnly] vaut `true`, ou l'ensemble de la classe côté enseignant, avec filtre par cours et export CSV.
  Widget _gradebook({required bool studentOnly}) {
    final rows = _controller.gradebook(
      courseId: _courseFilter,
      student: studentOnly ? _controller.currentUserId : null,
    );
    return ListView(
      // Désactive le défilement interne (`shrinkWrap` + `NeverScrollableScrollPhysics`) lorsqu'il est imbriqué dans `_teacherCopies`.
      shrinkWrap: studentOnly ? false : true,
      physics: studentOnly ? null : const NeverScrollableScrollPhysics(),
      padding: studentOnly ? const EdgeInsets.all(16) : EdgeInsets.zero,
      children: [
        Row(
          children: [
            const Expanded(
              child: SectionHeader(
                title: 'Carnet de notes',
                subtitle: 'GET /courses/:id/gradebook',
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _exportCsv(studentOnly: studentOnly),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Export CSV'),
            ),
          ],
        ),
        // Filtre déroulant par cours mettant à jour à la fois l'affichage et l'export CSV.
        DropdownButtonFormField<String?>(
          initialValue: _courseFilter,
          decoration: evalInputDecoration(label: 'Filtrer par cours'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Tous les cours')),
            ..._controller.accessibleCourses.map(
              (c) => DropdownMenuItem(value: c.id, child: Text(c.title)),
            ),
          ],
          onChanged: (v) => setState(() => _courseFilter = v),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const EmptyState(
            icon: Icons.insights_outlined,
            title: 'Pas encore de notes',
            subtitle: 'Passez un quiz ou attendez une correction.',
          ),
        ...rows.map(
          (r) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: evalCardDecoration(),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.itemTitle,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${r.itemType} · ${r.courseTitle}'
                        '${studentOnly ? '' : ' · ${r.studentName}'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: EduColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatGrade(r.grade, r.maxGrade),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    StatusChip(
                      label: r.status,
                      color: r.status == 'Noté'
                          ? EduColors.success
                          : EduColors.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Onglet « Documents » filtrable par cours (`DropdownButtonFormField`) et par dossier
  /// (`ChoiceChip` pour Polycopiés, Corrigés, Annales), ouvrant `DocumentDetailScreen` au clic.
  Widget _documents() {
    final docs = _controller.visibleDocuments(
      courseId: _courseFilter,
      folder: _folderFilter,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(
          title: 'Documents du cours',
          subtitle: 'Polycopiés, corrigés, annales',
        ),
        DropdownButtonFormField<String?>(
          initialValue: _courseFilter,
          decoration: evalInputDecoration(label: 'Cours'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Tous les cours')),
            ..._controller.accessibleCourses.map(
              (c) => DropdownMenuItem(value: c.id, child: Text(c.title)),
            ),
          ],
          onChanged: (v) => setState(() => _courseFilter = v),
        ),
        const SizedBox(height: 10),
        // Filtres par répertoire thématique disposés en Wrap.
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Tous'),
              selected: _folderFilter == null,
              onSelected: (_) => setState(() => _folderFilter = null),
            ),
            ...DocumentFolder.values.map(
              (f) => ChoiceChip(
                label: Text(f.label),
                selected: _folderFilter == f,
                onSelected: (_) => setState(() => _folderFilter = f),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (docs.isEmpty)
          const EmptyState(
            icon: Icons.folder_off_outlined,
            title: 'Aucun document',
            subtitle: 'Les fichiers publiés par l\'enseignant s\'affichent ici.',
          ),
        ...docs.map(
          (d) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: evalCardDecoration(),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: d.folder.color.withValues(alpha: 0.1),
                child: Icon(d.folder.icon, color: d.folder.color),
              ),
              title: Text(
                d.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${d.folder.label} · ${d.courseTitle}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  EvaluationsRoutes.documentDetail,
                  arguments: DocumentDetailArgs(documentId: d.id),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Affiche une boîte de dialogue modale ([AlertDialog]) demandant confirmation
  /// avant d'exécuter une suppression irréversible de quiz ou de devoir.
  Future<void> _confirmDelete(String message, VoidCallback onYes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmation'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) onYes();
  }

  /// Génère le contenu CSV du carnet de notes via [EvaluationsController.exportGradebookCsv]
  /// et l'affiche dans une feuille modale basse (`showModalBottomSheet`) avec copie vers le presse-papiers ([Clipboard]).
  Future<void> _exportCsv({required bool studentOnly}) async {
    final csv = _controller.exportGradebookCsv(
      courseId: _courseFilter,
      student: studentOnly ? _controller.currentUserId : null,
    );
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Export CSV du carnet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              // Aperçu sélectionnable et défilable du contenu CSV généré.
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: SingleChildScrollView(
                  child: SelectableText(
                    csv,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Copie la chaîne CSV dans le presse-papiers système puis referme la feuille modale avec notification SnackBar.
              PrimaryCta(
                label: 'Copier dans le presse-papiers',
                icon: Icons.copy_rounded,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: csv));
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('CSV copié. Collez-le dans Excel ou Sheets.')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
