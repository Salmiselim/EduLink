import 'package:flutter/material.dart';

import 'features/evaluations/data/evaluations_mock_data.dart';
import 'features/evaluations/models/evaluations_models.dart';
import 'features/evaluations/routes/evaluations_routes.dart';
import 'features/evaluations/screens/evaluations_screen.dart';
import 'features/evaluations/widgets/eval_ui.dart';
import 'features/marketplace/data/marketplace_mock_data.dart';
import 'features/marketplace/models/marketplace_models.dart';
import 'features/marketplace/routes/marketplace_routes.dart';
import 'features/marketplace/screens/marketplace_screen.dart';

/// Point d'entrée principal de l'application EduLink (intégration M4 + M5).
void main() {
  runApp(const EduLinkApp());
}

/// Widget racine de l'application qui configure :
/// - Le thème Material 3 (charte graphique EduLink — MARKETPLACE_GUIDE.md)
/// - Le générateur de routes combiné (`EduLinkRoutes.onGenerateRoute`)
/// - Le shell intégré [EduLinkShell] avec la barre de navigation à 5 onglets
class EduLinkApp extends StatelessWidget {
  const EduLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      onGenerateRoute: EduLinkRoutes.onGenerateRoute,
      home: const EduLinkShell(),
    );
  }
}

/// Répartiteur centralisé des routes nommées de tous les modules intégrés.
/// Chaque module expose son propre `onGenerateRoute` (qui retourne null si la
/// route ne lui appartient pas) : on les chaîne simplement dans l'ordre.
/// Un nouveau module (M1, M2, M3) n'a qu'à ajouter son appel ici.
class EduLinkRoutes {
  EduLinkRoutes._();

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final marketplaceRoute = MarketplaceRoutes.onGenerateRoute(settings);
    if (marketplaceRoute != null) return marketplaceRoute;
    final evaluationsRoute = EvaluationsRoutes.onGenerateRoute(settings);
    if (evaluationsRoute != null) return evaluationsRoute;
    return null;
  }
}

/// Shell intégré de l'application : une seule barre de navigation inférieure
/// à 5 onglets (Page 2 du Plan d'équipe) et un [IndexedStack] qui conserve
/// l'état de chaque module quand on change d'onglet.
/// - Onglet 2 : M4 · Évaluations (live)
/// - Onglet 3 : M5 · Marketplace (live)
/// - Onglets 0, 1, 4 : placeholders (M2 · Cours, M3 · Forum, M1 · Profil)
class EduLinkShell extends StatefulWidget {
  const EduLinkShell({super.key});

  @override
  State<EduLinkShell> createState() => _EduLinkShellState();
}

class _EduLinkShellState extends State<EduLinkShell> {
  /// Onglet affiché au démarrage : Marketplace (M5), module de référence.
  int _currentIndex = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _ModulePlaceholderTab(
            icon: Icons.menu_book_rounded,
            title: 'M2 · Cours',
            subtitle: 'Chapitres, contenu & progression',
            ownerLabel: 'Responsable : M2',
            branchLabel: 'Branche : cours',
          ),
          _ModulePlaceholderTab(
            icon: Icons.forum_rounded,
            title: 'M3 · Forum (Selim)',
            subtitle: 'Questions, réponses & réactions',
            ownerLabel: 'Responsable : Selim',
            branchLabel: 'Branche : QA',
          ),
          EvaluationsRoot(),
          MarketplaceRoot(),
          _ModulePlaceholderTab(
            icon: Icons.person_rounded,
            title: 'M1 · Profil & Badges',
            subtitle: 'Comptes, rôles, profils & badges',
            ownerLabel: 'Responsable : M1',
            branchLabel: 'Branche : feat/m1-user',
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        indicatorColor: const Color(0xFFDBEAFE),
        onDestinationSelected: (index) =>
            setState(() => _currentIndex = index),
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
            selectedIcon: Icon(Icons.quiz_rounded),
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
  }
}

/// Racine de l'onglet Marketplace (M5) : AppBar du module + écran principal.
/// Extrait de l'ancien `MarketplaceShell` (branche marketplace) : la barre
/// inférieure est désormais gérée par [EduLinkShell].
class MarketplaceRoot extends StatelessWidget {
  const MarketplaceRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = MarketplaceController.instance;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isTeacher = controller.currentUserRole == SellerRole.teacher;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            // Logo + Titre du module M5 Marketplace
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
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
                        'EduLink · Marketplace',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Ressources numériques, physiques & cours particuliers',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              // Bascule de rôle simulé (RoleAware : Étudiant / Enseignant vérifié)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  tooltip:
                      'Changer de rôle simulé (RoleAware : Étudiant / Enseignant vérifié)',
                  onPressed: controller.toggleCurrentUserRole,
                  backgroundColor: isTeacher
                      ? const Color(0xFFDBEAFE)
                      : const Color(0xFFF1F5F9),
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
              // Raccourci vers l'assistant de création d'offre (Métier 2)
              IconButton(
                tooltip: 'Publier une nouvelle offre (Assistant M5)',
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    MarketplaceRoutes.offerWizard,
                  );
                },
                icon: const Icon(
                  Icons.add_box_rounded,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          // Écran principal de la Marketplace (Explorer | Mes offres | Mes commandes)
          body: const MarketplaceScreen(),
        );
      },
    );
  }
}

/// Racine de l'onglet Évaluations (M4) : AppBar du module + écran principal.
/// Extrait de l'ancien `EvaluationsShell` (branche evaluations) : la barre
/// inférieure est désormais gérée par [EduLinkShell].
class EvaluationsRoot extends StatelessWidget {
  const EvaluationsRoot({super.key});

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
            // Logo + Titre du module M4 Évaluations
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
              const SizedBox(width: 4),
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

/// Onglet placeholder d'un module pas encore intégré (M1, M2 ou M3).
/// Reprend le style d'AppBar des autres modules et affiche la branche où le
/// travail réel est en cours.
class _ModulePlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String ownerLabel;
  final String branchLabel;

  const _ModulePlaceholderTab({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ownerLabel,
    required this.branchLabel,
  });

  @override
  Widget build(BuildContext context) {
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
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EduLink · ${_shortTitle(title)}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFDBEAFE),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: const Color(0xFF1D4ED8)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$ownerLabel · $branchLabel',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Module à venir — géré sur la branche de son responsable.',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  /// « M2 · Cours » → « Cours » (le préfixe module est déjà dans le titre AppBar)
  String _shortTitle(String title) {
    final parts = title.split('·');
    return parts.length > 1 ? parts.last.trim() : title;
  }
}
