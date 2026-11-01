import 'package:flutter/material.dart';
import '../data/evaluations_mock_data.dart';
import '../widgets/eval_ui.dart';

/// Écran de consultation des résultats d'un quiz.
/// Affiche la note obtenue sur une tentative précise (côté étudiant), le taux de réussite
/// global par question et, côté enseignant, la liste complète des copies remises.
class QuizResultsScreen extends StatelessWidget {
  final String quizId;
  final String? attemptId;
  const QuizResultsScreen({super.key, required this.quizId, this.attemptId});

  @override
  Widget build(BuildContext context) {
    final controller = EvaluationsController.instance;
    // S'abonne aux mises à jour de EvaluationsController afin de refléter toute nouvelle tentative soumise.
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final quiz = controller.quizById(quizId);
        if (quiz == null) {
          return const Scaffold(body: Center(child: Text('Quiz introuvable')));
        }
        // Charge la tentative ciblée lorsqu'un étudiant consulte son propre corrigé.
        final attempt = attemptId == null
            ? null
            : controller.attemptById(attemptId!);
        // Récupère l'ensemble des tentatives validées sur ce quiz pour calculer les statistiques par question.
        final all = controller.attemptsForQuiz(quizId)
            .where((a) => a.isSubmitted)
            .toList();

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
              // Carte d'en-tête rappelant le quiz et mettant en évidence le score sur 20 (vert si >= 10, rouge sinon).
              Container(
                padding: const EdgeInsets.all(16),
                decoration: evalCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quiz.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      quiz.courseTitle,
                      style: const TextStyle(color: EduColors.muted),
                    ),
                    if (attempt?.score != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        '${EvaluationsController.formatScore(attempt!.score!)} / 20',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: attempt.score! >= 10
                              ? EduColors.success
                              : EduColors.danger,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SectionHeader(
                title: 'Statistiques par question',
                subtitle: 'GET /quizzes/:id/results',
              ),
              // Parcourt chaque question pour calculer le ratio de réussite et afficher le corrigé détaillé.
              ...quiz.questions.asMap().entries.map((e) {
                final i = e.key;
                final q = e.value;
                final answered = all.where((a) => a.answers.length > i);
                // Compare les réponses triées de chaque copie aux indices attendus `q.correct`.
                final correctCount = answered.where((a) {
                  final given = [...a.answers[i]]..sort();
                  final expected = [...q.correct]..sort();
                  return given.toString() == expected.toString();
                }).length;
                final ratio = answered.isEmpty
                    ? 0.0
                    : correctCount / answered.length;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: evalCardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Q${i + 1}. ${q.text}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      // Jauge visuelle représentant la proportion d'étudiants ayant trouvé la bonne réponse.
                      LinearProgressIndicator(
                        value: ratio,
                        color: EduColors.success,
                        backgroundColor: EduColors.border,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$correctCount / ${answered.length} bonnes réponses',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: EduColors.muted,
                        ),
                      ),
                      // Détail individuel affiché lorsqu'une tentative spécifique a été fournie en argument.
                      if (attempt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Votre réponse : ${_labels(q.options, attempt.answers.length > i ? attempt.answers[i] : const [])}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          'Correction : ${_labels(q.options, q.correct)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: EduColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (q.explanation.isNotEmpty)
                          Text(
                            q.explanation,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: EduColors.textSecondary,
                            ),
                          ),
                      ],
                    ],
                  ),
                );
              }),
              // Section réservée à l'enseignant récapitulant les notes obtenues par chaque étudiant.
              if (controller.isTeacher) ...[
                const SizedBox(height: 8),
                const SectionHeader(title: 'Copies des étudiants'),
                ...all.map(
                  (a) => ListTile(
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: EduColors.border),
                    ),
                    title: Text(
                      a.studentName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('Tentative ${a.attemptNo}'),
                    trailing: Text(
                      '${EvaluationsController.formatScore(a.score ?? 0)} / 20',
                      style: const TextStyle(fontWeight: FontWeight.w800),
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

  /// Traduit une liste d'indices d'options en chaîne lisible séparée par des virgules.
  String _labels(List<String> options, List<int> indexes) {
    if (indexes.isEmpty) return '—';
    return indexes.map((i) => options[i]).join(', ');
  }
}
