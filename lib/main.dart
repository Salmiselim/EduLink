import 'package:flutter/material.dart';
import 'features/evaluations/data/evaluations_mock_data.dart';
import 'features/evaluations/models/evaluations_models.dart';
import 'features/evaluations/routes/evaluations_routes.dart';
import 'features/evaluations/screens/evaluations_screen.dart';
import 'features/evaluations/widgets/eval_ui.dart';

void main() {
  runApp(const EduLinkEvaluationsApp());
}

class EduLinkEvaluationsApp extends StatelessWidget {
  const EduLinkEvaluationsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduLink — Évaluations',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: EduColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: EduColors.scaffold,
      ),
      onGenerateRoute: EvaluationsRoutes.onGenerateRoute,
      home: const EvaluationsShell(),
    );
  }
}

class EvaluationsShell extends StatelessWidget {
  const EvaluationsShell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = EvaluationsController.instance;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isTeacher = controller.currentUserRole == UserRole.teacher;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: EduColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.quiz_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EduLink · Évaluations',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: EduColors.text,
                        ),
                      ),
                      Text(
                        'Quiz, dépôts, documents & carnet de notes',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: EduColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  tooltip: 'Changer de rôle simulé (RoleAware)',
                  onPressed: controller.toggleCurrentUserRole,
                  backgroundColor:
                      isTeacher ? EduColors.infoBg : EduColors.neutralBg,
                  avatar: Icon(
                    isTeacher
                        ? Icons.verified_rounded
                        : Icons.school_outlined,
                    size: 16,
                    color: isTeacher
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFF475569),
                  ),
                  label: Text(
                    isTeacher ? 'Rôle: Enseignant' : 'Rôle: Étudiant',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isTeacher
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFF334155),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: const EvaluationsScreen(),
          floatingActionButton: isTeacher
              ? FloatingActionButton.extended(
                  onPressed: () => _newEvalSheet(context),
                  backgroundColor: EduColors.primary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nouvelle évaluation'),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: 2,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            indicatorColor: EduColors.infoBg,
            onDestinationSelected: (index) {
              if (index != 2) {
                const names = [
                  'M2 · Cours',
                  'M3 · Forum (Selim)',
                  'M4 · Évaluations',
                  'M5 · Marketplace',
                  'M1 · Profil & Badges',
                ];
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 2),
                    content: Text(
                      'Onglet ${names[index]} : géré sur la branche de son responsable. Vous êtes sur M4 · Évaluations.',
                    ),
                  ),
                );
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book_rounded),
                label: 'Cours',
              ),
              NavigationDestination(
                icon: Icon(Icons.forum_outlined),
                selectedIcon: Icon(Icons.forum_rounded),
                label: 'Forum',
              ),
              NavigationDestination(
                icon: Icon(Icons.quiz_outlined),
                selectedIcon: Icon(
                  Icons.quiz_rounded,
                  color: Color(0xFF1D4ED8),
                ),
                label: 'Évaluations',
              ),
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront_rounded),
                label: 'Marketplace',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profil',
              ),
            ],
          ),
        );
      },
    );
  }

  void _newEvalSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Créer',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.quiz_rounded, color: EduColors.primary),
                title: const Text('Quiz'),
                subtitle: const Text('Assistant + brouillon Gemini'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, EvaluationsRoutes.quizWizard);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.assignment_rounded,
                  color: EduColors.warning,
                ),
                title: const Text('Devoir (dépôt)'),
                subtitle: const Text('Consignes, échéance, note max'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(
                    context,
                    EvaluationsRoutes.assignmentWizard,
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.folder_rounded,
                  color: Color(0xFF7C3AED),
                ),
                title: const Text('Document'),
                subtitle: const Text('Polycopié, corrigé ou annales'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(
                    context,
                    EvaluationsRoutes.documentWizard,
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
