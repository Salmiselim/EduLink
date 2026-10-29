import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/forum_provider.dart';
import 'routes/app_routes.dart';
import 'screens/forum_feed_screen.dart';

import 'features/auth/screens/sign_in_screen.dart';
import 'features/courses/data/courses_mock_data.dart';
import 'features/courses/models/courses_models.dart';
import 'features/courses/routes/courses_routes.dart';
import 'features/courses/screens/courses_screen.dart';
import 'features/evaluations/data/evaluations_mock_data.dart';
import 'features/evaluations/models/evaluations_models.dart';
import 'features/evaluations/routes/evaluations_routes.dart';
import 'features/evaluations/screens/evaluations_screen.dart';
import 'features/evaluations/widgets/eval_ui.dart';
import 'features/marketplace/data/marketplace_mock_data.dart';
import 'features/marketplace/models/marketplace_models.dart';
import 'features/marketplace/routes/marketplace_routes.dart';
import 'features/marketplace/screens/marketplace_screen.dart';

/// Point d'entrée principal de l'application EduLink.
/// Le shell intégré [EduLinkShell] est ouvert après la connexion (ou via le
/// bouton « Passer » de l'écran de démonstration).
void main() {
  runApp(const EduLinkApp());
}

/// Widget racine de l'application qui configure :
/// - Le thème Material 3 (charte graphique EduLink — MARKETPLACE_GUIDE.md)
/// - Le générateur de routes combiné (`EduLinkRoutes.onGenerateRoute`)
/// - Le shell intégré [EduLinkShell] avec la barre de navigation à 5 onglets
class EduLinkApp extends StatelessWidget {
  const EduLinkApp({super.key});
class EduLinkApp extends StatelessWidget {
  const EduLinkApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5), // EduLink Indigo
          primary: const Color(0xFF4F46E5),
          secondary: const Color(0xFF0EA5E9),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FD),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          centerTitle: false,
        ),
      ),
      home: const MainNavigationScreen(),
      onGenerateRoute: AppRoutes.onGenerateRoute,
      onUnknownRoute: AppRoutes.onUnknownRoute,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      onGenerateRoute: EduLinkRoutes.onGenerateRoute,
      home: const SignInScreen(),
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
    final coursesRoute = CoursesRoutes.onGenerateRoute(settings);
    if (coursesRoute != null) return coursesRoute;
    final marketplaceRoute = MarketplaceRoutes.onGenerateRoute(settings);
    if (marketplaceRoute != null) return marketplaceRoute;
    final evaluationsRoute = EvaluationsRoutes.onGenerateRoute(settings);
    if (evaluationsRoute != null) return evaluationsRoute;
    return null;
  }
}

/// Shell intégré de l'application : une seule barre de navigation inférieure
/// à 5 onglets et un [IndexedStack] qui conserve l'état de chaque module
/// quand on change d'onglet.
/// - Onglet 0 : Cours (live)
/// - Onglet 2 : Évaluations (live)
/// - Onglet 3 : Marketplace (live)
/// - Onglets 1, 4 : placeholders (Forum, Profil)
class EduLinkShell extends StatefulWidget {
  const EduLinkShell({super.key});

  @override
  State<EduLinkShell> createState() => _EduLinkShellState();
}

class _EduLinkShellState extends State<EduLinkShell> {
  /// Onglet affiché au démarrage : Cours.
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          CoursesRoot(),
          _ModulePlaceholderTab(
            icon: Icons.forum_rounded,
            title: 'Forum',
            subtitle: 'Questions, réponses & réactions',
            ownerLabel: 'Intégration à venir',
            branchLabel: 'Forum',
          ),
          EvaluationsRoot(),
          MarketplaceRoot(),
          _ModulePlaceholderTab(
            icon: Icons.person_rounded,
            title: 'Profil & Badges',
            subtitle: 'Comptes, rôles, profils & badges',
            ownerLabel: 'Intégration à venir',
            branchLabel: 'Auth & Profils',
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

/// Racine de l'onglet Cours (M2) : AppBar du module + écran principal.
/// Intégré dans le shell unifié : la barre inférieure est
/// désormais gérée par [EduLinkShell].
class CoursesRoot extends StatelessWidget {
  const CoursesRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = CoursesController.instance;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isTeacher = controller.currentUserRole == CourseRole.teacher;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            // Logo + Titre du module Cours
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
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
                        'EduLink · Cours',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Chapitres, contenu & progression',
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
              // Raccourci vers l'assistant de création de cours (Métier 1) :
              // réservé à l'enseignant (CoursesController.isTeacher)
              if (isTeacher)
                IconButton(
                  tooltip: 'Créer un cours (Assistant M2)',
                  onPressed: () {
                    Navigator.pushNamed(context, CoursesRoutes.courseWizard);
                  },
                  icon: const Icon(
                    Icons.add_box_rounded,
                    color: Color(0xFF2563EB),
                  ),
                ),
              const SizedBox(width: 4),
            ],
          ),
          // Écran principal du module Cours (Mes cours | Catalogue / Statistiques)
          body: const CoursesScreen(),
        );
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  // Onglets du plan v3 : Cours · Forum · Évaluations · Marketplace · Profil
  static const int _forumTab = 1;
  int _currentIndex = _forumTab;

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  final List<Widget> _screens = const [
    _PlaceholderTab(
      title: 'Cours',
      member: 'Membre 2',
      icon: Icons.menu_book_rounded,
    ),
    ForumFeedScreen(), // Onglet M3 : Forum Q&A
    _PlaceholderTab(
      title: 'Évaluations',
      member: 'Membre 4',
      icon: Icons.assignment_outlined,
    ),
    _PlaceholderTab(
      title: 'Marketplace',
      member: 'Membre 5',
      icon: Icons.storefront_outlined,
    ),
    _PlaceholderTab(
      title: 'Profil',
      member: 'Membre 1',
      icon: Icons.person_outline_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: Colors.white,
          indicatorColor: Colors.indigo.shade100,
          elevation: 0,
          onDestinationSelected: _switchTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book, color: Colors.indigo),
              label: 'Cours',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum, color: Colors.indigo),
              label: 'Forum',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment, color: Colors.indigo),
              label: 'Évaluations',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront, color: Colors.indigo),
              label: 'Marketplace',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: Colors.indigo),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final String title;
  final String member;
  final IconData icon;

  const _PlaceholderTab({
    required this.title,
    required this.member,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
