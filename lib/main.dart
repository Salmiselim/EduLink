import 'package:flutter/material.dart';
import 'features/marketplace/data/marketplace_mock_data.dart';
import 'features/marketplace/models/marketplace_models.dart';
import 'features/marketplace/screens/marketplace_screen.dart';
import 'features/marketplace/screens/offer_wizard_screen.dart';

/// Point d'entrée principal de l'application EduLink (Module M5 — Marketplace).
void main() {
  runApp(const EduLinkMarketplaceApp());
}

/// Widget racine de l'application qui configure le thème Material 3
/// et définit `MarketplaceShell` comme écran d'accueil.
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
      home: const MarketplaceShell(),
    );
  }
}

/// Enveloppe principale (Shell) de l'onglet Marketplace.
/// Contient :
/// - L'AppBar supérieure avec le titre du module
/// - Le bouton de bascule de rôle simulé (Étudiant <-> Enseignant vérifié) pour tester RoleAware & Règle 5
/// - Le raccourci '+' vers l'assistant de création d'offre (`OfferWizardScreen`)
/// - Le corps principal `MarketplaceScreen` (Explorer | Mes offres | Mes commandes)
class MarketplaceShell extends StatelessWidget {
  const MarketplaceShell({super.key});

  @override
  Widget build(BuildContext context) {
    // Récupération du contrôleur partagé (singleton ChangeNotifier)
    final controller = MarketplaceController.instance;

    // ListenableBuilder reconstruit automatiquement l'interface quand le rôle change
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
              // Bouton rapide pour pousser la route de l'Assistant de création d'offre (Métier 2)
              IconButton(
                tooltip: 'Publier une nouvelle offre (Assistant M5)',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OfferWizardScreen(),
                    ),
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
        );
      },
    );
  }
}
