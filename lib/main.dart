// Bibliothèque officielle Material Design de Flutter : fournit MaterialApp, Scaffold,
// AppBar, NavigationBar, ActionChip, IconButton, SnackBar, ThemeData et ColorScheme.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'features/auth/services/auth_service.dart';
import 'features/auth/screens/sign_in_screen.dart';
import 'features/courses/data/courses_mock_data.dart';
import 'features/courses/models/courses_models.dart';
import 'features/courses/routes/courses_routes.dart';
import 'features/courses/screens/courses_screen.dart';
import 'features/courses/services/courses_push_service.dart';
import 'features/evaluations/data/evaluations_mock_data.dart';
import 'features/evaluations/models/evaluations_models.dart';
import 'features/evaluations/routes/evaluations_routes.dart';
import 'features/evaluations/screens/evaluations_screen.dart';
import 'features/evaluations/widgets/eval_ui.dart';
import 'features/marketplace/data/marketplace_mock_data.dart';
import 'features/marketplace/models/marketplace_models.dart';
import 'features/marketplace/routes/marketplace_routes.dart';
import 'features/marketplace/services/marketplace_firestore_service.dart';
import 'features/marketplace/screens/marketplace_screen.dart';
import 'features/profil/screens/profile_screen.dart';
import 'providers/forum_provider.dart';
import 'routes/app_routes.dart';
import 'screens/forum_feed_screen.dart';

/// Point d'entrée principal de l'application EduLink.
/// Le shell intégré [EduLinkShell] est ouvert après la connexion
/// (réelle ou en mode démonstration si Firebase est indisponible).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadEnv();
  await _initFirebase();
  runApp(const EduLinkApp());
}

/// Charge le fichier `.env` (clé Gemini) sans jamais bloquer le démarrage :
/// si le fichier est absent ou illisible, l'IA est simplement « non
/// configurée » et les écrans affichent leur message d'aide habituel.
Future<void> _loadEnv() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (error) {
    debugPrint('.env non chargé — IA non configurée : $error');
  }
}

/// Initialise Firebase puis branche la Marketplace sur Cloud Firestore.
/// Si Firebase n'est pas encore configuré (pas de google-services.json), l'appli
/// reste utilisable avec les données en mémoire.
Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Notifications push (FCM) : permission + jeton enregistré dans
    // users/{uid} ; sans effet hors Android/iOS (repli silencieux).
    unawaited(CoursesPushService.init());
    MarketplaceFirestoreService.enableOfflinePersistence();
    CoursesController.firebaseReady = true;
    AuthService.onSignedIn = (user) async {
      await CoursesController.instance.connectCloud();
      await MarketplaceController.instance.connectFirestore();
      await EvaluationsController.instance.connectCloud();
      // Ré-enregistre le jeton FCM pour le compte qui vient de se connecter.
      unawaited(CoursesPushService.refreshForCurrentUser());
    };
    // Connexion aux collections Firestore en arrière-plan (amélioration QA)
    // pour ne jamais bloquer l'affichage initial ; les erreurs réseau sont
    // gérées à l'intérieur de chaque contrôleur (repli démonstration).
    unawaited(MarketplaceController.instance.connectFirestore());
    unawaited(CoursesController.instance.connectCloud());
  } catch (e) {
    debugPrint('Firebase non configuré, mode hors Firestore : $e');
  }
}

/// Widget racine de l'application qui configure :
/// - Le thème Material 3 (charte graphique EduLink)
/// - Le générateur de routes combiné (`EduLinkRoutes.onGenerateRoute`)
/// - Le shell intégré [EduLinkShell] avec la barre de navigation à 5 onglets
class EduLinkApp extends StatelessWidget {
  const EduLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Forum (M3)
        ChangeNotifierProvider(create: (_) => ForumProvider()),
      ],
      child: MaterialApp(
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
        home: const SignInScreen(),
      ),
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
    final forumRoute = ForumRoutes.onGenerateRoute(settings);
    if (forumRoute != null) return forumRoute;
    return null;
  }
}

/// Shell intégré de l'application : une seule barre de navigation inférieure
/// à 5 onglets et un [IndexedStack] qui conserve l'état de chaque module
/// quand on change d'onglet.
/// - Onglet 0 : Cours (live)
/// - Onglet 1 : placeholder (Forum) · Onglet 4 : Profil (live)
/// - Onglet 2 : Évaluations (live)
/// - Onglet 3 : Marketplace (live)
/// - Onglet 4 : placeholder (Profil)
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
          ForumFeedScreen(),
          EvaluationsRoot(),
          MarketplaceRoot(),
          ProfileScreen(),
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
              // Cloche des notifications in-app (nouveaux chapitres,
              // publications) alimentée en temps réel par Firestore.
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => _showNotificationsSheet(context, controller),
                icon: Badge(
                  isLabelVisible: controller.unreadNotificationCount > 0,
                  label: Text('${controller.unreadNotificationCount}'),
                  backgroundColor: const Color(0xFFDC2626),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
              // Bascule de rôle simulé — visible uniquement en mode démonstration
              // (en mode réel, le rôle vient du compte Firebase).
              if (controller.isDemoMode)
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
                  tooltip: 'Créer un cours (Assistant cours)',
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

  /// Feuille modale listant les notifications in-app de l'utilisateur
  /// (nouveaux chapitres, publications de cours), avec marquage « lu ».
  void _showNotificationsSheet(
    BuildContext context,
    CoursesController controller,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final notifications = controller.myNotifications;
            final unread = controller.unreadNotificationCount;
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.62,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.notifications_rounded,
                            color: Color(0xFF2563EB),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Notifications',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (unread > 0)
                            TextButton(
                              onPressed: controller.markAllMyNotificationsRead,
                              child: const Text(
                                'Tout marquer comme lu',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: notifications.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.notifications_none_rounded,
                                    size: 40,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Aucune notification pour le moment. Les '
                                    'nouveautés de vos cours (nouveaux '
                                    'chapitres, publications) apparaîtront ici.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.5,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: notifications.length,
                              itemBuilder: (context, index) {
                                final notification = notifications[index];
                                final date = notification.createdAt;
                                return ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: notification.read
                                          ? const Color(0xFFF1F5F9)
                                          : const Color(0xFFDBEAFE),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      notification.icon,
                                      size: 18,
                                      color: notification.read
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFF2563EB),
                                    ),
                                  ),
                                  title: Text(
                                    notification.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: notification.read
                                          ? FontWeight.w600
                                          : FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${notification.body}\n'
                                    '${notification.courseTitle} · '
                                    '${date.day.toString().padLeft(2, '0')}/'
                                    '${date.month.toString().padLeft(2, '0')}'
                                    '/${date.year}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      height: 1.4,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  isThreeLine: true,
                                  onTap: () => controller
                                      .markNotificationRead(notification.id),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Racine de l'onglet Marketplace (M5) : AppBar du module + écran principal.
/// Extrait de du `MarketplaceShell` d'origine : la barre
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

        // `Scaffold` : structure visuelle Material 3 standard fournissant :
        // - `appBar` (en-tête fixe en haut)
        // - `body` (contenu principal : `MarketplaceScreen`)
        // - `bottomNavigationBar` (barre de navigation à 5 onglets de l'application EduLink)
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            // Logo + Titre du module Marketplace
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
              // Bascule de rôle simulé — visible uniquement en mode démonstration
              // (en mode réel, le rôle vient du compte Firebase).
              if (controller.isDemoMode)
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
/// Extrait de du `EvaluationsShell` d'origine : la barre
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
            // Logo + Titre du module Évaluations
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
                  onPressed: controller.toggleRole,
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
