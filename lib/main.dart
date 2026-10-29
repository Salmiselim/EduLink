// Bibliothèque officielle Material Design de Flutter : fournit MaterialApp, Scaffold,
// AppBar, NavigationBar, ActionChip, IconButton, SnackBar, ThemeData et ColorScheme.
import 'package:flutter/material.dart';

// Liaisons internes vers les couches du module M5 (Data, Models, Routes, Screens) :
import 'features/marketplace/data/marketplace_mock_data.dart';
import 'features/marketplace/models/marketplace_models.dart';
import 'features/marketplace/routes/marketplace_routes.dart';
import 'features/marketplace/screens/marketplace_screen.dart';

/// Point d'entrée principal de l'application EduLink (Module M5 — Marketplace).
/// `runApp` (fourni par `package:flutter/widgets.dart` via `material.dart`) monte
/// le widget racine [EduLinkMarketplaceApp] en haut de l'arbre de widgets Flutter.
void main() {
  runApp(const EduLinkMarketplaceApp());
}

/// Widget racine (`StatelessWidget` car sa configuration globale ne possède pas d'état local mutable).
/// Configure :
/// 1. `MaterialApp` : enveloppe Material Design gérant le thème global et le `Navigator` racine.
/// 2. `ThemeData` + `useMaterial3: true` + `ColorScheme.fromSeed` : charte graphique unifiée EduLink
///    basée sur le bleu primaire `#2563EB` et le fond ardoise clair `#F8FAFC`.
/// 3. `onGenerateRoute: MarketplaceRoutes.onGenerateRoute` : branchement du routeur centralisé
///    qui intercepte tous les appels `Navigator.pushNamed(...)` du module.
/// 4. `home: MarketplaceShell()` : écran d'accueil contenant l'AppBar et la barre à 5 onglets.
class EduLinkMarketplaceApp extends StatelessWidget {
  const EduLinkMarketplaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduLink — Marketplace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      initialRoute: MarketplaceRoutes.home,
      onGenerateRoute: MarketplaceRoutes.onGenerateRoute,
      home: const MarketplaceShell(),
    );
  }
}

/// Enveloppe principale (Shell) de l'onglet Marketplace.
/// Contient :
/// - L'AppBar supérieure avec le titre du module
/// - Le bouton de bascule de rôle simulé (Étudiant <-> Enseignant vérifié) pour tester RoleAware & Règle 5
/// - Le raccourci '+' vers l'assistant de création d'offre (`MarketplaceRoutes.offerWizard`)
/// - Le corps principal `MarketplaceScreen` (Explorer | Mes offres | Mes commandes)
/// - La barre de navigation inférieure à 5 onglets (Page 2 du Plan d'équipe) positionnée sur `Marketplace`
class MarketplaceShell extends StatelessWidget {
  const MarketplaceShell({super.key});

  @override
  Widget build(BuildContext context) {
    // Récupération de l'instance unique (Singleton) du contrôleur d'état `MarketplaceController`.
    // Ce contrôleur hérite de `ChangeNotifier` (`package:flutter/foundation.dart`).
    final controller = MarketplaceController.instance;

    // `ListenableBuilder` (widget réactif natif de Flutter) s'abonne à `controller`.
    // Dès que `controller.notifyListeners()` est appelé (ex: bascule Étudiant <-> Enseignant),
    // seul ce sous-arbre est reconstruit automatiquement sans recréer toute l'application.
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
              // Bouton permettant de simuler le changement de rôle (users.role : student | teacher)
              // Permet de vérifier le badge « Offre étudiant » vs « Enseignant vérifié » lors de la création d'offre
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
              // Bouton rapide pour pousser la route nommée de l'Assistant de création d'offre (Métier 2)
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
          // Écran principal de la Marketplace (avec la bascule Explorer | Mes offres | Mes commandes)
          body: const MarketplaceScreen(),

          // Barre de navigation inférieure (5 onglets définis en Page 2 du Plan d'équipe)
          // Positionnée sur l'onglet 3 : Marketplace (M5)
          bottomNavigationBar: NavigationBar(
            selectedIndex: 3,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            indicatorColor: const Color(0xFFDBEAFE),
            onDestinationSelected: (index) {
              if (index != 3) {
                const moduleNames = [
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
                      'Onglet ${moduleNames[index]} : géré sur la branche de son responsable. Vous êtes sur M5 · Marketplace.',
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
                selectedIcon: Icon(Icons.quiz_rounded),
                label: 'Évaluations',
              ),
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(
                  Icons.storefront_rounded,
                  color: Color(0xFF1D4ED8),
                ),
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
}
