import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/evaluations_mock_data.dart';
import '../models/evaluations_models.dart';
import '../routes/evaluations_routes.dart';
import '../widgets/eval_ui.dart';

class EvaluationsScreen extends StatefulWidget {
  const EvaluationsScreen({super.key});

  @override
  State<EvaluationsScreen> createState() => _EvaluationsScreenState();
}

class _EvaluationsScreenState extends State<EvaluationsScreen> {
  final _controller = EvaluationsController.instance;
  final _search = TextEditingController();
  int _section = 0;
  String _typeFilter = 'all';
  String? _courseFilter;
  DocumentFolder? _folderFilter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final teacher = _controller.isTeacher;
        return Column(
          children: [
            // Sélecteur de sous-vues (SegmentedButton)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  segments: teacher
                      ? const [
                          ButtonSegment(
                            value: 0,
                            label: Text('Mes évaluations'),
                            icon: Icon(Icons.library_books_rounded, size: 18),
                          ),
                          ButtonSegment(
                            value: 1,
                            label: Text('Copies & Notes'),
                            icon: Icon(Icons.rate_review_rounded, size: 18),
                          ),
                          ButtonSegment(
                            value: 2,
                            label: Text('Documents'),
                            icon: Icon(Icons.folder_rounded, size: 18),
                          ),
                        ]
                      : const [
                          ButtonSegment(
                            value: 0,
                            label: Text('À faire'),
                            icon: Icon(Icons.assignment_turned_in_rounded, size: 18),
                          ),
                          ButtonSegment(
                            value: 1,
                            label: Text('Carnet de notes'),
                            icon: Icon(Icons.insights_rounded, size: 18),
                          ),
                          ButtonSegment(
                            value: 2,
                            label: Text('Documents'),
                            icon: Icon(Icons.folder_rounded, size: 18),
                          ),
                        ],
                  selected: {_section},
                  onSelectionChanged: (s) => setState(() => _section = s.first),
                ),
              ),
            ),

            // Contenu principal
            Expanded(
              child: teacher
                  ? (_section == 0
                      ? _teacherEvaluations()
                      : _section == 1
                          ? _teacherCopiesAndGradebook()
                          : _documentsView())
                  : (_section == 0
                      ? _studentTodoView()
                      : _section == 1
                          ? _studentGradebookView()
                          : _documentsView()),
            ),
          ],
        );
      },
    );
  }

  Widget _searchBar({required String hint}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        decoration: evalInputDecoration(
          label: 'Recherche',
          hint: hint,
          icon: Icons.search_rounded,
          suffixIcon: _search.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _search.clear();
                    setState(() {});
                  },
                )
              : null,
        ),
      ),
    );
  }

  // ==========================================================================
  // VUES ÉTUDIANT
  // ==========================================================================

  Widget _studentTodoView() {
    final studentId = _controller.currentUserId;
    final avg = _controller.calculateStudentAverage(studentId);
    final pendingCount = _controller.studentPendingTodoCount(studentId);
    final completedCount = _controller.studentCompletedCount(studentId);

    final q = _search.text.trim().toLowerCase();
    final quizzes = _controller.publishedQuizzesForStudent().where((item) {
      if (_typeFilter == 'assignment') return false;
      return q.isEmpty ||
          item.title.toLowerCase().contains(q) ||
          item.courseTitle.toLowerCase().contains(q);
    }).toList();

    final assignments = _controller.assignmentsForStudent().where((item) {
      if (_typeFilter == 'quiz') return false;
      return q.isEmpty ||
          item.title.toLowerCase().contains(q) ||
          item.courseTitle.toLowerCase().contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // Cartes statistiques en-tête
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: KpiStatCard(
                  title: 'Moyenne générale',
                  value: avg != null ? '$avg / 20' : '—',
                  icon: Icons.trending_up_rounded,
                  color: avg != null && avg >= 10 ? EduColors.success : EduColors.primary,
                  subtitle: avg != null ? (avg >= 10 ? 'Admis' : 'En rattrapage') : 'Pas encore noté',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: KpiStatCard(
                  title: 'Évaluations à rendre',
                  value: '$pendingCount',
                  icon: Icons.schedule_rounded,
                  color: pendingCount > 0 ? EduColors.warning : EduColors.muted,
                  subtitle: '$completedCount terminée(s)',
                ),
              ),
            ],
          ),
        ),

        _searchBar(hint: 'Rechercher un quiz ou un devoir…'),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Tout voir'),
                selected: _typeFilter == 'all',
                onSelected: (_) => setState(() => _typeFilter = 'all'),
              ),
              ChoiceChip(
                label: const Text('Quiz uniquement'),
                selected: _typeFilter == 'quiz',
                onSelected: (_) => setState(() => _typeFilter = 'quiz'),
              ),
              ChoiceChip(
                label: const Text('Devoirs uniquement'),
                selected: _typeFilter == 'assignment',
                onSelected: (_) => setState(() => _typeFilter = 'assignment'),
              ),
            ],
          ),
        ),

        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SectionHeader(
            title: 'Évaluations à venir & En cours',
            subtitle: 'GET /evaluations/upcoming · Quiz et dépôts de devoirs',
          ),
        ),

        if (quizzes.isEmpty && assignments.isEmpty)
          const EmptyState(
            icon: Icons.done_all_rounded,
            title: 'Aucune évaluation en attente',
            subtitle: 'Toutes vos évaluations sont à jour pour les cours suivis.',
          ),

        ...quizzes.map(_studentQuizCard),
        ...assignments.map(_studentAssignmentCard),
      ],
    );
  }

  Widget _studentQuizCard(Quiz quiz) {
    final count = _controller.attemptCountFor(quiz.id, _controller.currentUserId);
    final attempts = _controller.attemptsForQuiz(
      quiz.id,
      student: _controller.currentUserId,
    ).where((a) => a.isSubmitted).toList();
    attempts.sort((a, b) => b.attemptNo.compareTo(a.attemptNo));
    final last = attempts.isNotEmpty ? attempts.first : null;
    final canTake = _controller.canTakeQuiz(quiz);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
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
              if (last != null && last.score != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: last.score! >= 10 ? EduColors.successBg : EduColors.dangerBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${EvaluationsController.formatScore(last.score!)} / 20',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: last.score! >= 10 ? EduColors.success : EduColors.danger,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            quiz.title,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: EduColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${quiz.questions.length} questions · Durée ${quiz.timeLimitMin} min · Tentative(s) : $count/${quiz.attemptsAllowed}',
            style: const TextStyle(fontSize: 12.5, color: EduColors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            'Échéance : ${formatDate(quiz.dueDate)}',
            style: const TextStyle(fontSize: 12, color: EduColors.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (canTake)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      EvaluationsRoutes.quizTake,
                      arguments: QuizTakeArgs(quizId: quiz.id),
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(count == 0 ? 'Commencer le quiz' : 'Retenter le quiz'),
                  style: FilledButton.styleFrom(backgroundColor: EduColors.primary),
                ),
              if (!canTake && last == null)
                const StatusChip(
                  label: 'Indisponible (hors période)',
                  color: EduColors.muted,
                ),
              if (last != null) ...[
                if (canTake) const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      EvaluationsRoutes.quizResults,
                      arguments: QuizResultsArgs(
                        quizId: quiz.id,
                        attemptId: last.id,
                      ),
                    );
                  },
                  icon: const Icon(Icons.insights_rounded, size: 16),
                  label: const Text('Voir le résultat'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _studentAssignmentCard(Assignment assignment) {
    final sub = _controller.submissionFor(
      assignment.id,
      _controller.currentUserId,
    );
    final canSubmit = _controller.canSubmitAssignment(assignment);
    final isLate = DateTime.now().isAfter(assignment.dueDate);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: EduColors.successBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    formatGrade(sub!.grade, assignment.maxGrade),
                    style: const TextStyle(fontWeight: FontWeight.w900, color: EduColors.success),
                  ),
                )
              else if (sub != null)
                const StatusChip(
                  label: 'Déposé (en attente)',
                  color: EduColors.warning,
                )
              else if (isLate)
                StatusChip(
                  label: assignment.allowLate ? 'Retard toléré' : 'Date dépassée',
                  color: EduColors.danger,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            assignment.title,
            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: EduColors.text),
          ),
          const SizedBox(height: 4),
          Text(
            'Barème : ${assignment.maxGrade.toStringAsFixed(0)} pts · Échéance : ${formatDate(assignment.dueDate)}',
            style: const TextStyle(fontSize: 12.5, color: EduColors.muted),
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(
              'Déposé le ${formatDate(sub.submittedAt)}${sub.isLate ? " (en retard)" : ""}',
              style: TextStyle(
                fontSize: 12,
                color: sub.isLate ? EduColors.danger : EduColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: canSubmit
                ? () {
                    Navigator.pushNamed(
                      context,
                      EvaluationsRoutes.assignmentSubmit,
                      arguments: AssignmentSubmitArgs(assignmentId: assignment.id),
                    );
                  }
                : null,
            icon: Icon(sub == null ? Icons.upload_rounded : Icons.edit_rounded, size: 18),
            label: Text(sub == null ? 'Déposer mon travail' : 'Modifier mon dépôt'),
            style: FilledButton.styleFrom(
              backgroundColor: canSubmit ? EduColors.primary : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _studentGradebookView() {
    final studentId = _controller.currentUserId;
    final avg = _controller.calculateStudentAverage(studentId);
    final rows = _controller.gradebook(
      courseId: _courseFilter,
      student: studentId,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: SectionHeader(
                title: 'Carnet de notes personnel',
                subtitle: 'GET /courses/:id/gradebook · Quiz & Devoirs',
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _exportCsv(studentOnly: true),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Export CSV'),
            ),
          ],
        ),

        // Carte récapitulative moyenne
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: evalCardDecoration(),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (avg != null && avg >= 10 ? EduColors.success : EduColors.primary)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.auto_graph_rounded,
                  color: avg != null && avg >= 10 ? EduColors.success : EduColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Moyenne générale calculée',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: EduColors.muted),
                    ),
                    Text(
                      avg != null ? '$avg / 20' : 'Pas encore de note',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: avg != null && avg >= 10 ? EduColors.success : EduColors.text,
                      ),
                    ),
                    Text(
                      '${rows.where((r) => r.grade != null).length} évaluation(s) notée(s)',
                      style: const TextStyle(fontSize: 11.5, color: EduColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        DropdownButtonFormField<String?>(
          initialValue: _courseFilter,
          decoration: evalInputDecoration(label: 'Filtrer par cours', icon: Icons.filter_list_rounded),
          items: [
            const DropdownMenuItem(value: null, child: Text('Tous les cours suivis')),
            ..._controller.accessibleCourses.map(
              (c) => DropdownMenuItem(value: c.id, child: Text(c.title)),
            ),
          ],
          onChanged: (v) => setState(() => _courseFilter = v),
        ),
        const SizedBox(height: 14),

        if (rows.isEmpty)
          const EmptyState(
            icon: Icons.insights_rounded,
            title: 'Aucune note pour le moment',
            subtitle: 'Vos notes apparaîtront dès que vous aurez soumis un quiz ou qu\'une copie aura été corrigée.',
          ),

        ...rows.map(
          (r) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: evalCardDecoration(),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusChip(
                            label: r.itemType,
                            color: r.itemType == 'Quiz' ? EduColors.primary : EduColors.warning,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            r.courseTitle,
                            style: const TextStyle(fontSize: 12, color: EduColors.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        r.itemTitle,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                      ),
                      if (r.datedAt != null)
                        Text(
                          'Évalué le ${formatDate(r.datedAt!)}',
                          style: const TextStyle(fontSize: 11.5, color: EduColors.muted),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatGrade(r.grade, r.maxGrade),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: (r.grade != null && (r.grade! / r.maxGrade) >= 0.5)
                            ? EduColors.success
                            : EduColors.danger,
                      ),
                    ),
                    const SizedBox(height: 4),
                    StatusChip(
                      label: r.status,
                      color: r.status == 'Noté' ? EduColors.success : EduColors.warning,
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

  // ==========================================================================
  // VUES ENSEIGNANT
  // ==========================================================================

  Widget _teacherEvaluations() {
    final pendingCount = _controller.pendingCopiesCount;
    final totalQuizzes = _controller.quizzes.length;
    final totalAsg = _controller.assignments.length;

    final q = _search.text.trim().toLowerCase();
    final quizzes = _controller.quizzes.where((item) {
      if (_typeFilter == 'assignment') return false;
      return q.isEmpty || item.title.toLowerCase().contains(q);
    }).toList();

    final assignments = _controller.assignments.where((item) {
      if (_typeFilter == 'quiz') return false;
      return q.isEmpty || item.title.toLowerCase().contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        // Cartes statistiques en-tête
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: KpiStatCard(
                  title: 'Évaluations créées',
                  value: '${totalQuizzes + totalAsg}',
                  icon: Icons.quiz_rounded,
                  color: EduColors.primary,
                  subtitle: '$totalQuizzes quiz · $totalAsg devoirs',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: KpiStatCard(
                  title: 'Copies à corriger',
                  value: '$pendingCount',
                  icon: Icons.rate_review_rounded,
                  color: pendingCount > 0 ? EduColors.danger : EduColors.success,
                  subtitle: pendingCount > 0 ? 'En attente d\'évaluation' : 'Tout est corrigé',
                ),
              ),
            ],
          ),
        ),

        _searchBar(hint: 'Rechercher une évaluation créée…'),

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
            title: 'Gestion des évaluations',
            subtitle: 'CRUD complet · Publication · Statistiques promotion',
          ),
        ),

        ...quizzes.map((quiz) {
          final attemptsCount = _controller
              .attemptsForQuiz(quiz.id)
              .where((a) => a.isSubmitted)
              .length;

          return Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: evalCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusChip(
                      label: quiz.isPublished ? 'Publié' : 'Brouillon',
                      color: quiz.isPublished ? EduColors.success : EduColors.muted,
                    ),
                    const SizedBox(width: 6),
                    StatusChip(
                      label: quiz.courseTitle,
                      color: EduColors.primary,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Supprimer ce quiz',
                      icon: const Icon(Icons.delete_outline_rounded, color: EduColors.danger, size: 20),
                      onPressed: () => _confirmDelete(
                        'Êtes-vous certain de vouloir supprimer le quiz « ${quiz.title} » ? Toutes les tentatives associées seront supprimées.',
                        () => _controller.deleteQuiz(quiz.id),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  quiz.title,
                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: EduColors.text),
                ),
                const SizedBox(height: 4),
                Text(
                  '${quiz.questions.length} questions · Durée ${quiz.timeLimitMin} min · $attemptsCount copie(s) reçue(s)',
                  style: const TextStyle(color: EduColors.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          EvaluationsRoutes.quizWizard,
                          arguments: QuizWizardArgs(existing: quiz),
                        );
                      },
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Modifier'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          EvaluationsRoutes.quizResults,
                          arguments: QuizResultsArgs(quizId: quiz.id),
                        );
                      },
                      icon: const Icon(Icons.bar_chart_rounded, size: 16),
                      label: Text('Statistiques ($attemptsCount)'),
                    ),
                    FilledButton.tonal(
                      onPressed: () => _controller.publishQuiz(quiz.id, !quiz.isPublished),
                      child: Text(quiz.isPublished ? 'Masquer' : 'Publier'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),

        ...assignments.map((asg) {
          final pending = _controller.submissions
              .where((s) => s.assignmentId == asg.id && s.status == SubmissionStatus.submitted)
              .length;

          return Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(16),
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
                      label: asg.courseTitle,
                      color: EduColors.primary,
                    ),
                    const Spacer(),
                    if (pending > 0)
                      StatusChip(
                        label: '$pending à corriger',
                        color: EduColors.danger,
                      ),
                    IconButton(
                      tooltip: 'Supprimer ce devoir',
                      icon: const Icon(Icons.delete_outline_rounded, color: EduColors.danger, size: 20),
                      onPressed: () => _confirmDelete(
                        'Supprimer définitivement le devoir « ${asg.title} » et tous ses dépôts ?',
                        () => _controller.deleteAssignment(asg.id),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  asg.title,
                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: EduColors.text),
                ),
                const SizedBox(height: 4),
                Text(
                  'Barème : ${asg.maxGrade.toStringAsFixed(0)} pts · Échéance : ${formatDate(asg.dueDate)}',
                  style: const TextStyle(color: EduColors.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      EvaluationsRoutes.assignmentWizard,
                      arguments: AssignmentWizardArgs(existing: asg),
                    );
                  },
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Modifier le devoir'),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _teacherCopiesAndGradebook() {
    final copies = _controller.copiesToGrade();
    final gradebookRows = _controller.gradebook(courseId: _courseFilter);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(
          title: 'Copies en attente de correction',
          subtitle: '${copies.length} copie(s) à évaluer (PATCH /submissions/:id/grade)',
        ),

        if (copies.isEmpty)
          const EmptyState(
            icon: Icons.task_alt_rounded,
            title: 'Aucune copie en attente',
            subtitle: 'Toutes les copies soumises par vos étudiants ont été corrigées.',
          )
        else
          ...copies.map((sub) {
            final asg = _controller.assignmentById(sub.assignmentId);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: evalCardDecoration(),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: EduColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    sub.studentName.substring(0, 1),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: EduColors.primary),
                  ),
                ),
                title: Text(
                  sub.studentName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${asg?.title ?? ""} · Remis le ${formatDate(sub.submittedAt)}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (sub.isLate)
                      const StatusChip(label: 'Retard', color: EduColors.danger),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
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

        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: SectionHeader(
                title: 'Carnet de notes de la promotion',
                subtitle: 'GET /courses/:id/gradebook · Vue globale enseignant',
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _exportCsv(studentOnly: false),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Export CSV'),
            ),
          ],
        ),

        DropdownButtonFormField<String?>(
          initialValue: _courseFilter,
          decoration: evalInputDecoration(label: 'Filtrer par cours', icon: Icons.filter_list_rounded),
          items: [
            const DropdownMenuItem(value: null, child: Text('Tous mes cours')),
            ..._controller.accessibleCourses.map(
              (c) => DropdownMenuItem(value: c.id, child: Text(c.title)),
            ),
          ],
          onChanged: (v) => setState(() => _courseFilter = v),
        ),
        const SizedBox(height: 12),

        ...gradebookRows.map(
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
                        r.studentName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      Text(
                        '${r.itemType} · ${r.itemTitle} (${r.courseTitle})',
                        style: const TextStyle(fontSize: 12, color: EduColors.muted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatGrade(r.grade, r.maxGrade),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                    ),
                    StatusChip(
                      label: r.status,
                      color: r.status == 'Noté' ? EduColors.success : EduColors.warning,
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

  // ==========================================================================
  // VUE DOCUMENTS (COMMUNE ÉTUDIANT & ENSEIGNANT — FAÇON BLACKBOARD)
  // ==========================================================================

  Widget _documentsView() {
    final docs = _controller.visibleDocuments(
      courseId: _courseFilter,
      folder: _folderFilter,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: SectionHeader(
                title: 'Espace Documents du cours',
                subtitle: 'Documents classés par dossiers (façon Blackboard)',
              ),
            ),
            if (_controller.isTeacher)
              FilledButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, EvaluationsRoutes.documentWizard);
                },
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Nouveau document'),
              ),
          ],
        ),

        DropdownButtonFormField<String?>(
          initialValue: _courseFilter,
          decoration: evalInputDecoration(label: 'Filtrer par cours', icon: Icons.menu_book_rounded),
          items: [
            const DropdownMenuItem(value: null, child: Text('Tous les cours')),
            ..._controller.accessibleCourses.map(
              (c) => DropdownMenuItem(value: c.id, child: Text(c.title)),
            ),
          ],
          onChanged: (v) => setState(() => _courseFilter = v),
        ),
        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Tous les dossiers'),
              selected: _folderFilter == null,
              onSelected: (_) => setState(() => _folderFilter = null),
            ),
            ...DocumentFolder.values.map(
              (f) => ChoiceChip(
                avatar: Icon(f.icon, size: 16, color: _folderFilter == f ? Colors.white : f.color),
                label: Text(f.label),
                selected: _folderFilter == f,
                selectedColor: f.color,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _folderFilter == f ? Colors.white : EduColors.textSecondary,
                ),
                onSelected: (_) => setState(() => _folderFilter = f),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (docs.isEmpty)
          const EmptyState(
            icon: Icons.folder_off_outlined,
            title: 'Aucun document trouvé',
            subtitle: 'Aucun document ne correspond aux filtres sélectionnés.',
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
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
              ),
              subtitle: Text(
                '${d.folder.label} · ${d.courseTitle} · ${d.downloadsCount} téléchargement(s)',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Télécharger',
                    icon: const Icon(Icons.download_rounded, color: EduColors.primary),
                    onPressed: () {
                      _controller.incrementDownload(d.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${d.fileUrl} téléchargé.')),
                      );
                    },
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
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

  // ==========================================================================
  // HELPERS MODALES & DIALOGUES
  // ==========================================================================

  Future<void> _confirmDelete(String message, VoidCallback onYes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmation de suppression'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: EduColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) onYes();
  }

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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: EduColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.table_chart_rounded, color: EduColors.primary),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Export CSV du carnet de notes',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Format compatible Excel et Google Sheets (GET /courses/:id/gradebook) :',
                style: TextStyle(fontSize: 12.5, color: EduColors.muted),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: EduColors.neutralBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: EduColors.border),
                ),
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: SelectableText(
                    csv,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryCta(
                label: 'Copier les données CSV',
                icon: Icons.copy_rounded,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: csv));
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: EduColors.success,
                        content: Text('Données CSV copiées dans le presse-papiers avec succès.'),
                      ),
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
