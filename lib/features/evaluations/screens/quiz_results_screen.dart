import 'package:flutter/material.dart';
import '../data/evaluations_mock_data.dart';
import '../widgets/eval_ui.dart';

class QuizResultsScreen extends StatelessWidget {
  final String quizId;
  final String? attemptId;
  const QuizResultsScreen({super.key, required this.quizId, this.attemptId});

  @override
  Widget build(BuildContext context) {
    final controller = EvaluationsController.instance;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final quiz = controller.quizById(quizId);
        if (quiz == null) {
          return const Scaffold(
            body: Center(child: Text('Quiz introuvable.')),
          );
        }
        final attempt = attemptId == null
            ? (controller.attemptsForQuiz(quizId, student: controller.currentUserId)
                .where((a) => a.isSubmitted)
                .firstOrNull)
            : controller.attemptById(attemptId!);

        final allSubmitted = controller
            .attemptsForQuiz(quizId)
            .where((a) => a.isSubmitted)
            .toList();

        final hasPassed = (attempt?.score ?? 0) >= 10;

        return Scaffold(
          backgroundColor: EduColors.scaffold,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Text(
              'Résultats du quiz',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: EduColors.text,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Carte récapitulative
              Container(
                padding: const EdgeInsets.all(18),
                decoration: evalCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusChip(
                          label: quiz.courseTitle,
                          color: EduColors.primary,
                        ),
                        const Spacer(),
                        if (attempt != null)
                          StatusChip(
                            label: hasPassed ? 'Réussi (≥ 10/20)' : 'Échoué (< 10/20)',
                            color: hasPassed ? EduColors.success : EduColors.danger,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      quiz.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: EduColors.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enseignant : ${quiz.teacherName} · ${quiz.questions.length} questions',
                      style: const TextStyle(color: EduColors.muted, fontSize: 13),
                    ),
                    if (attempt?.score != null) ...[
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Note obtenue :',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: EduColors.muted,
                                ),
                              ),
                              Text(
                                '${EvaluationsController.formatScore(attempt!.score!)} / 20',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: hasPassed ? EduColors.success : EduColors.danger,
                                ),
                              ),
                            ],
                          ),
                          if (attempt.submittedAt != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Soumis le :',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: EduColors.muted,
                                  ),
                                ),
                                Text(
                                  formatDate(attempt.submittedAt!),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: EduColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const SectionHeader(
                title: 'Statistiques par question',
                subtitle: 'GET /quizzes/:id/results · Analyse de la promotion',
              ),

              ...quiz.questions.asMap().entries.map((e) {
                final i = e.key;
                final q = e.value;
                final answered = allSubmitted.where((a) => a.answers.length > i);
                final correctCount = answered.where((a) {
                  final given = [...a.answers[i]]..sort();
                  final expected = [...q.correct]..sort();
                  return given.toString() == expected.toString();
                }).length;
                final ratio = answered.isEmpty ? 0.0 : correctCount / answered.length;
                final percentage = (ratio * 100).round();

                final studentGiven = (attempt != null && attempt.answers.length > i)
                    ? attempt.answers[i]
                    : <int>[];
                final sortedGiven = [...studentGiven]..sort();
                final sortedExpected = [...q.correct]..sort();
                final studentIsCorrect = sortedGiven.toString() == sortedExpected.toString();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: evalCardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusChip(
                            label: 'Q${i + 1} · ${q.points.toStringAsFixed(0)} pt(s)',
                            color: EduColors.primary,
                          ),
                          const Spacer(),
                          Text(
                            '$percentage % de réussite',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: percentage >= 50 ? EduColors.success : EduColors.danger,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        q.text,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: EduColors.text,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ratio,
                          color: percentage >= 50 ? EduColors.success : EduColors.danger,
                          backgroundColor: EduColors.border,
                          minHeight: 7,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$correctCount sur ${answered.length} étudiant(s) ont répondu juste',
                        style: const TextStyle(fontSize: 12, color: EduColors.muted),
                      ),

                      if (attempt != null) ...[
                        const Divider(height: 20),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: studentIsCorrect
                                ? EduColors.successBg.withValues(alpha: 0.5)
                                : EduColors.dangerBg.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: studentIsCorrect ? EduColors.success : EduColors.danger,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    studentIsCorrect
                                        ? Icons.check_circle_rounded
                                        : Icons.cancel_rounded,
                                    size: 16,
                                    color: studentIsCorrect
                                        ? EduColors.success
                                        : EduColors.danger,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    studentIsCorrect ? 'Votre réponse est correcte' : 'Votre réponse est incorrecte',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                      color: studentIsCorrect
                                          ? EduColors.success
                                          : EduColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Votre sélection : ${_labels(q.options, studentGiven)}',
                                style: const TextStyle(fontSize: 13, color: EduColors.textSecondary),
                              ),
                              if (!studentIsCorrect)
                                Text(
                                  'Bonne(s) réponse(s) : ${_labels(q.options, q.correct)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: EduColors.success,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (q.explanation.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline_rounded, size: 15, color: EduColors.muted),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  q.explanation,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: EduColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                );
              }),

              // Section réservée à l'enseignant : Liste des copies
              if (controller.isTeacher) ...[
                const SizedBox(height: 16),
                const SectionHeader(
                  title: 'Copies soumises par les étudiants',
                  subtitle: 'Toutes les tentatives enregistrées sur ce quiz',
                ),
                if (allSubmitted.isEmpty)
                  const EmptyState(
                    icon: Icons.assignment_late_outlined,
                    title: 'Aucune tentative soumise',
                    subtitle: 'Les étudiants n\'ont pas encore passé ce quiz.',
                  )
                else
                  ...allSubmitted.map(
                    (a) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: evalCardDecoration(),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: EduColors.infoBg,
                          child: Text(
                            a.studentName.substring(0, 1),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: EduColors.primary,
                            ),
                          ),
                        ),
                        title: Text(
                          a.studentName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          'Tentative n°${a.attemptNo} · ${a.submittedAt != null ? formatDate(a.submittedAt!) : ""}',
                          style: const TextStyle(fontSize: 12, color: EduColors.muted),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (a.score ?? 0) >= 10 ? EduColors.successBg : EduColors.dangerBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${EvaluationsController.formatScore(a.score ?? 0)} / 20',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: (a.score ?? 0) >= 10 ? EduColors.success : EduColors.danger,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _labels(List<String> options, List<int> indexes) {
    if (indexes.isEmpty) return 'Aucune sélection';
    return indexes.map((i) => (i >= 0 && i < options.length) ? options[i] : '?').join(', ');
  }
}
