# EduLink — Guide du Module Marketplace & Design System

> **Module** : Marketplace (*Ressources numériques, Ressources physiques & Cours particuliers*)  
> **Statut** : interfaces prêtes pour intégration  
> **Version SDK** : Flutter `3.47.8` · Dart `^3.13.5` (`3.13.7`) · Material 3 activé  

Ce document sert à la fois de **documentation complète du travail réalisé sur le module Marketplace** et de **charte graphique / Design System de référence** (polices, tailles, couleurs, espacements, composants) pour que tous les modules (**Cours, Forum, Évaluations, Marketplace, Profil**) gardent une interface 100 % cohérente.

---

## 1. Design System & Charte Graphique (pour tous les modules)

### 1.1 Polices de caractères (Fonts) & Typographie
Le projet utilise la typographie **Material 3 native** de Flutter (`useMaterial3: true` dans `ThemeData`) ainsi que la police `monospace` pour les codes techniques et identifiants :
- **Police principale (Sans-Serif)** :
  - **Android** : `Roboto` (par défaut Flutter Material 3)
  - **iOS / macOS** : `SF Pro Text` / `SF Pro Display`
  - **Windows** : `Segoe UI`
- **Police secondaire (Monospace)** : `fontFamily: 'monospace'` (utilisée pour les codes techniques comme `resource_digital` ou les badges d'endpoints).
- **Icônes** : `uses-material-design: true` dans `pubspec.yaml` — utilisation privilégiée des variantes **`_rounded`** et **`_outlined`** de `Icons` (ex. `Icons.storefront_rounded`, `Icons.verified_rounded`, `Icons.calendar_month_rounded`).

#### Échelle Typographique (Tailles & Graisses à réutiliser dans tous les modules)

| Usage dans l'interface | `fontSize` | `fontWeight` | Couleur | Exemple |
| :--- | :--- | :--- | :--- | :--- |
| **Titre de page / Détail d'offre** | `20.0` | `FontWeight.w900` (Black) | `#0F172A` | Titre principal dans `OfferDetailScreen` |
| **Prix principal (Barre du bas)** | `19.0` | `FontWeight.w900` (Black) | `#0F172A` ou `#15803D` | `35 TND / h`, `Gratuit (0 TND)` |
| **Titre d'AppBar / Étape Wizard** | `17.0` – `18.0` | `FontWeight.w800` (ExtraBold) | `#0F172A` | `EduLink · Marketplace`, `Réserver un créneau` |
| **Titre de section / Carte** | `15.5` – `16.0` | `FontWeight.w700` / `w800` | `#0F172A` | Titre d'une `OfferCard`, `Description & Particularités` |
| **Corps de texte (Description / Chat)** | `13.5` – `14.0` | `FontWeight.w400` / `w500` | `#334155` | Description d'une offre (`height: 1.5`), bulle de message |
| **Sous-titre / Métadonnées** | `12.0` – `12.5` | `FontWeight.w600` | `#475569` / `#64748B` | Université du vendeur, nombre de vues/ventes, créneau |
| **Badges & Puces (Chips)** | `11.0` – `11.5` | `FontWeight.w700` (Bold) | Couleur sémantique | `Enseignant vérifié`, `Offre étudiant`, `Numérique (PDF)` |
| **Horodatage & Étiquettes techniques** | `10.0` – `10.5` | `FontWeight.w600` | `#64748B` | Heure d'un message (`14:16`), `Snapshot Firestore` |

---

### 1.2 Palette de Couleurs (Hex Codes)

#### Couleurs de base (Thème général EduLink)
| Rôle | Code Hex | Code Flutter | Utilisation |
| :--- | :--- | :--- | :--- |
| **Primary (Bleu EduLink)** | `#2563EB` | `Color(0xFF2563EB)` | Couleur principale (`seedColor`), boutons d'action, liens, bulles de chat envoyées |
| **Primary Dark** | `#1E3A8A` | `Color(0xFF1E3A8A)` | Dégradé du tableau de bord vendeur, textes d'accentuation |
| **Scaffold Background** | `#F8FAFC` | `Color(0xFFF8FAFC)` | Fond gris-bleuté très clair de tous les écrans |
| **Surface / Card** | `#FFFFFF` | `Colors.white` | Fond des cartes, de l'AppBar et des feuilles modales |
| **Border / Divider** | `#E2E8F0` | `Color(0xFFE2E8F0)` / `Colors.grey.shade200` | Bordures fines (`1px`) des cartes et séparateurs |
| **Text Primary (Slate 900)** | `#0F172A` | `Color(0xFF0F172A)` | Titres principaux et montants |
| **Text Secondary (Slate 700)** | `#334155` | `Color(0xFF334155)` | Descriptions, noms de vendeurs, valeurs techniques |
| **Text Muted (Slate 500/600)** | `#64748B` | `Color(0xFF64748B)` | Sous-titres, compteurs secondaires, placeholders |

#### Couleurs par Type d'Offre (`OfferType`)
| Type d'offre | Code Firestore | Couleur Principale | Fond de Badge (10% alpha) | Icône |
| :--- | :--- | :--- | :--- | :--- |
| **Ressource numérique** | `resource_digital` | `#2563EB` (Bleu) | `Color(0xFF2563EB).withValues(alpha: 0.1)` | `Icons.picture_as_pdf_rounded` |
| **Ressource physique** | `resource_physical` | `#D97706` (Ambre) | `Color(0xFFD97706).withValues(alpha: 0.1)` | `Icons.menu_book_rounded` |
| **Cours particulier** | `private_lesson` | `#7C3AED` (Violet) | `Color(0xFF7C3AED).withValues(alpha: 0.1)` | `Icons.co_present_rounded` |

#### Couleurs des Statuts (`OfferStatus` & `OrderStatus`)
| Statut | Couleur | Code Flutter | Utilisation |
| :--- | :--- | :--- | :--- |
| **Succès / Publiée / Terminée / Gratuit** | Vert Émeraude | `#16A34A` / Fond `#DCFCE7` | Offre `published`, Commande `completed`, Créneau `Libre`, Prix `Gratuit` |
| **En cours / Acceptée / Enseignant vérifié** | Bleu Royal | `#2563EB` / Fond `#DBEAFE` | Commande `accepted`, Badge `Enseignant vérifié` |
| **Attention / En attente / Masquée / Étoiles ★** | Ambre / Or | `#D97706` / `#F59E0B` / Fond `#FEF3C7` | Commande `requested`, Offre `hidden`, Notes ★, Badges `Vendeur`/`Mentor` |
| **Danger / Refusée / Épuisée / Signalement** | Rouge | `#DC2626` / `#EF4444` | Commande `rejected`, Offre `sold_out`, Cœur favori ♥, Signalement `POST /reports` |
| **Neutre / Brouillon / Annulée** | Gris Ardoise | `#64748B` / Fond `#F1F5F9` | Offre `draft`, Commande `cancelled`, Badge `Offre étudiant` |

---

### 1.3 Formes, Bordures & Espacements (Layout Rules)
- **Cartes (`Card` / `Container`)** :
  - `elevation: 0` (design plat moderne avec bordure subtile `Border.all(color: Colors.grey.shade200)`).
  - `borderRadius: BorderRadius.circular(16)` pour les cartes standard et `BorderRadius.circular(20)` pour les bannières d'en-tête.
- **Boutons (`FilledButton` / `OutlinedButton`)** :
  - Hauteur des CTA principaux en bas d'écran : `height: 50`, `borderRadius: BorderRadius.circular(14)`.
- **Feuilles modales (`BottomSheet`)** :
  - `borderRadius: BorderRadius.vertical(top: Radius.circular(24))`.
- **Marges d'écran** :
  - `padding: EdgeInsets.all(16)` sur tous les `ListView` principaux.

---

## 2. Architecture du Code de la Marketplace (`lib/features/marketplace/`)

```
lib/
├── main.dart                                      # Point d'entrée, Thème Material 3, Bascule Rôle (Étudiant/Enseignant)
└── features/marketplace/
    ├── models/
    │   └── marketplace_models.dart                # Enums & Classes correspondant aux collections Firestore
    ├── data/
    │   └── marketplace_mock_data.dart             # MarketplaceController (ChangeNotifier) + Données de démo
    ├── widgets/
    │   ├── offer_card.dart                        # Carte d'offre réutilisable (Catalogue & Recommandations L6)
    │   └── review_dialog.dart                     # Feuille modale de notation (1 à 5 ★) après commande terminée
    └── screens/
        ├── marketplace_screen.dart                # Onglet Marketplace : Explorer | Mes offres | Mes commandes
        ├── offer_detail_screen.dart               # Route poussée : Détail d'une offre, créneaux, avis, signalement
        ├── offer_wizard_screen.dart               # Route poussée : Assistant de création d'offre en 6 étapes
        ├── order_checkout_screen.dart             # Route poussée : Commande / Réservation et verrouillage de créneau
        └── order_chat_screen.dart                 # Route poussée : Chat temps réel par commande + Jitsi + PDF
```

### Diagramme de Navigation et de Flux d'État

```mermaid
flowchart TD
    Shell["main.dart (MarketplaceShell)"] --> MainTab["marketplace_screen.dart (MarketplaceScreen)"]
    Shell -->|"Bouton + (AppBar)"| Wizard["offer_wizard_screen.dart (OfferWizardScreen - 6 étapes)"]

    subgraph Onglet Marketplace (Bascule 3 vues)
        MainTab --> V1["Vue 1 : Explorer (Catalogue, Recherche, Filtres, Recommandations L6)"]
        MainTab --> V2["Vue 2 : Mes offres (Stats Vendeur, CRUD Offres & Créneaux)"]
        MainTab --> V3["Vue 3 : Mes commandes (Mes achats Acheteur | Demandes reçues Vendeur)"]
    end

    V1 -->|"Clic sur OfferCard"| Detail["offer_detail_screen.dart (OfferDetailScreen)"]
    V2 -->|"Bouton + Nouvelle offre"| Wizard
    V2 -->|"Bouton Aperçu"| Detail
    Detail -->|"Commander / Réserver un créneau"| Checkout["order_checkout_screen.dart (OrderCheckoutScreen)"]
    Checkout -->|"Verrouille le créneau & Crée la commande"| Chat["order_chat_screen.dart (OrderChatScreen)"]
    V3 -->|"Bouton Chat commande"| Chat
    V3 -->|"Bouton Laisser un avis ★"| Review["review_dialog.dart (ReviewBottomSheet)"]
    Chat -->|"Bouton Laisser un avis ★"| Review
```

---

## 3. Modèles de Données & Correspondance Firestore (`marketplace_models.dart`)

Tous les modèles suivent strictement le schéma de données validé en équipe :

| Collection Firestore | Classe Dart | Champs implémentés |
| :--- | :--- | :--- |
| **`offers`** | `Offer` | `id`, `sellerId`, `sellerName`, `sellerAvatar`, `sellerSubtitle`, `sellerBadges[]`, `sellerRole` (`student` \| `teacher`), `type` (`resource_digital` \| `resource_physical` \| `private_lesson`), `title`, `subject`, `level`, `description`, `images[]`, `price` (TND, `0` = gratuit), `fileUrl` (privé, digital), `condition` (`neuf` \| `bon` \| `usagé`), `quantity` (stock physique), `mode` (`online` \| `onsite`), `location` (`{address, city, lat, lng}`), `courseId` (nullable, Liaison L6), `courseTitle`, `status` (`draft` \| `published` \| `sold_out` \| `hidden`), `viewsCount`, `salesCount`, `ratingAvg`, `ratingCount`, `reportsCount`, `createdAt` |
| **`availabilities`** | `AvailabilitySlot` | `id`, `offerId`, `sellerId`, `date`, `startTime`, `endTime`, `isBooked`, `orderId` |
| **`orders`** | `MarketplaceOrder` | `id`, `offerId`, `offerTitle`, `offerType`, `offerSubject`, `buyerId`, `buyerName`, `sellerId`, `sellerName`, `sellerRole`, `quantity`, `amount` (TND), `slotId` (nullable), `slotLabel`, `meetingLink` (Jitsi Meet), `pickupAddress`, `fileUrl`, `status` (`requested` \| `accepted` \| `completed` \| `rejected` \| `cancelled`), `note`, `createdAt`, `updatedAt`, `unreadCount`, `hasReview` |
| **`reviews`** | `OfferReview` | `id` (= `orderId`, **1 seul avis par commande**), `buyerId`, `buyerName`, `buyerRoleLabel`, `sellerId`, `offerId`, `rating` (1–5), `comment`, `createdAt` |
| **`favorites`** | `Set<String>` | Stocke les `offerId` mis en favoris par l'utilisateur (`isFavorite`, `toggleFavorite`) |
| **`reports`** | `reportOffer()` | Incrémente `reportsCount` avec un motif ; **masque automatiquement l'offre (`status = hidden`) dès 3 signalements** |
| **`conversations/{id}/messages`** | `ChatMessage` | `id`, `orderId`, `senderId`, `senderName`, `text`, `attachmentUrl`, `attachmentLabel`, `readAt`, `createdAt`, `isSystemMessage` |

---

## 4. Détail des Interfaces et des 3 Métiers Implémentés

### Métier 1 : Catalogue, Recherche, Filtres, Recommandations (L6) & Signalement
Implémenté dans **`MarketplaceScreen` (Vue « Explorer »)** et **`OfferDetailScreen`** :
1. **Recherche & Filtres multicritères (`GET /offers?...`)** :
   - Barre de recherche instantanée (titre, description, matière, nom du vendeur).
   - Filtre **Favoris uniquement ♥** (`PUT|DELETE /favorites`).
   - Puces rapides par type (`Ressource numérique`, `Ressource physique`, `Cours particulier`) et par origine (`Enseignant vérifié`).
   - Feuille modale **Filtres & Tri du Catalogue** :
     - **Tri (`sort`)** : Pertinence (`viewsCount`), Prix croissant, Prix décroissant, Meilleure note ★.
     - **Origine du vendeur (`sellerRole`)** : Tous, `Enseignant vérifié`, `Offre étudiant`.
     - **Matière (`subject`)** : Algorithmique, Bases de Données, Réseaux & Sécurité, IA, Génie Logiciel, Mathématiques, Développement Mobile.
     - **Niveau (`level`)** : `L1`, `L2`, `L3`, `M1`, `M2`.
     - **Prix max (`maxPrice`)** : Curseur de `0 TND` (Gratuit uniquement) à `100 TND`.
     - **Mode (`mode`) & Ville (`city`)** : En ligne (Jitsi), En présentiel, filtre par ville (Tunis, Ariana, Manouba, Sousse, Sfax, Monastir).
     - **Note minimale ★** : `4.0+`, `4.5+`, `4.8+`.
2. **Recommandations d'après les cours suivis (Liaison L6 — `GET /offers/recommended`)** :
   - Carrousel horizontal en haut de la vue « Explorer » mettant en avant les offres rattachées aux cours suivis par l'étudiant.
3. **Origine du vendeur & Règle 5 (Page 2)** :
   - Chaque offre affiche clairement **« Offre étudiant »** ou **« Enseignant vérifié »**.
   - Sur `OfferDetailScreen`, si l'offre appartient à l'utilisateur connecté (`offer.sellerId == currentUserId`), le bouton d'achat est verrouillé avec la mention **« Votre propre offre (Règle 5) »**.
4. **Signalement automatique (`POST /reports`)** :
   - Boîte de dialogue sur `OfferDetailScreen` permettant de choisir un motif de signalement. Au **3ᵉ signalement**, l'offre passe automatiquement au statut `hidden` et disparaît du catalogue public.

---

### Métier 2 : Assistant de Création d'Offre (6 étapes) & Tableau de Bord Vendeur
Implémenté dans **`OfferWizardScreen`** (route poussée) et **`MarketplaceScreen` (Vue « Mes offres »)** :
1. **Assistant de création d'offre en 6 étapes (`OfferWizardScreen`)** :
   - **Étape 1 (`Type d'offre`)** : Choix entre `resource_digital`, `resource_physical` et `private_lesson`.
   - **Étape 2 (`Infos & Médias — L10`)** : Titre, matière, niveau, description, sélection du fichier PDF privé (`fileUrl` Cloudinary) pour le numérique, ou de l'état (`Neuf`, `Bon état`, `Usagé`) et du stock (`quantity`) pour le physique + ajout de photos (`images[]`).
   - **Étape 3 (`Prix en TND`)** : Bascule « Offre gratuite (0 TND) » ou saisie du tarif en TND (ou TND/h) + rappel du paiement hors-application.
   - **Étape 4 (`Mode, Lieu OpenStreetMap & Créneaux`)** :
     - Choix `En ligne (Jitsi Meet)` ou `En présentiel`.
     - Sélection de la ville et géocodage d'adresse **OpenStreetMap Nominatim**.
     - Ajout/suppression de créneaux de disponibilité (`availabilities`) pour les cours particuliers.
   - **Étape 5 (`Cours lié optionnel — Liaison L6`)** : Permet de rattacher l'offre à un cours (`offers.courseId`).
   - **Étape 6 (`Aperçu & Publication`)** : Récapitulatif complet avec double bouton **« Brouillon (`draft`) »** ou **« Publier l'offre (`published`) »**.
2. **Tableau de bord vendeur (`GET /seller/stats`)** :
   - Affiche en temps réel : **Vues totales**, **Ventes**, **Séances données (1h)**, **Note moyenne ★**, ainsi que les **Badges** (*Vendeur*, *Mentor*, *Bien noté*).
   - Gestion rapide de ses offres : filtrage par statut, boutons **Publier / Masquer** (`PATCH /offers/:id/publish|hide`), bouton **Créneaux (`availabilities` CRUD)**, **Aperçu**, et **Supprimer**.

---

### Métier 3 : Commandes, Réservations, Chat Temps Réel & Avis
Implémenté dans **`OrderCheckoutScreen`**, **`MarketplaceScreen` (Vue « Mes commandes »)**, **`OrderChatScreen`** et **`ReviewBottomSheet`** :
1. **Prise de commande / Réservation (`OrderCheckoutScreen` — `POST /orders`)** :
   - **Cours particulier** : sélection d'un créneau libre (`availabilities`) qui est immédiatement **verrouillé** (`isBooked = true`) pour empêcher toute double réservation.
   - **Ressource physique** : sélecteur de quantité dans la limite du stock disponible + rappel du point de remise OpenStreetMap.
   - **Ressource numérique** : déblocage immédiat si l'offre est gratuite (`0 TND`), sinon déblocage à l'acceptation par le vendeur.
2. **Gestion Acheteur / Vendeur (`GET /orders/me?as=buyer|seller`)** :
   - Sous-bascule **« Mes achats »** (Acheteur) et **« Demandes reçues »** (Vendeur).
   - **Côté Vendeur** : boutons **Accepter** (génère automatiquement le lien de visio **Jitsi Meet** `https://meet.jit.si/edulink-...`, débloque le PDF privé ou décrémente le stock physique), **Refuser** (libère le créneau), puis **Marquer comme terminée** (`completed`).
   - **Côté Acheteur** : boutons **Annuler** (tant que `requested`), **Télécharger PDF** (`GET /orders/:id/download`), et **Laisser un avis ★** (dès que `completed`).
3. **Chat lié à la commande (`OrderChatScreen` — Snapshots Firestore)** :
   - Bandeau récapitulatif épinglé en haut avec statut, montant TND, créneau, bouton **Rejoindre Jitsi Meet** et bouton **Télécharger PDF**.
   - Fil de discussion avec messages système automatiques, bulles horodatées, envoi de pièces jointes Cloudinary (`attachmentUrl`) et accusés de lecture (`✓✓`).
4. **Avis vérifiés (`ReviewBottomSheet` — `POST /reviews`)** :
   - Feuille modale 1 à 5 ★ + commentaire. Recalcule immédiatement `ratingAvg` et `ratingCount` sur l'offre et empêche un second avis sur la même commande (`id = orderId`).

---

## 5. Conformité aux Critères de Qualité

| Critère d'évaluation | Implémentation dans le module Marketplace |
| :--- | :--- |
| **1. Respect de la charte graphique** | Palette Material 3 unifiée (`#2563EB` Primary, `#F8FAFC` Scaffold, badges sémantiques par type d'offre et statut), typographie hiérarchisée, cartes à bordures fines `1px` et `borderRadius: 16`. |
| **2. Utilisation des composants adéquats** | `NavigationBar` (5 onglets), `SegmentedButton`, `FilterChip`, `ChoiceChip`, `Slider`, `SwitchListTile`, `DropdownButtonFormField`, `DraggableScrollableSheet`, `Badge`, `FloatingActionButton.extended`, `AlertDialog`. |
| **3. Navigation et gestion des routes** | Routeur centralisé dans `lib/features/marketplace/routes/marketplace_routes.dart` (`MarketplaceRoutes.onGenerateRoute`) avec routes nommées (`/marketplace/offer-detail`, `/marketplace/offer-wizard`, `/marketplace/order-checkout`, `/marketplace/order-chat`) et classes d'arguments typées (`OfferDetailArgs`, `OfferWizardArgs`, `OrderCheckoutArgs`, `OrderChatArgs`). |
| **4. Contrôles de saisie et validations** | Formulaires `Form` avec `GlobalKey<FormState>` et `AutovalidateMode.onUserInteraction` partout :<br>• **Assistant d'offre (`OfferWizardScreen`)** : Titre obligatoire (5–80 car., non numérique), Description obligatoire (20–600 car.), Prix TND numérique (`> 0` et `≤ 500 TND`), Adresse OpenStreetMap obligatoire (min. 6 car.), Créneaux horaires validés par regex `HH:mm` avec `Fin > Début` et au moins 1 créneau requis.<br>• **Commande (`OrderCheckoutScreen`)** : Créneau libre obligatoire + note au vendeur obligatoire (10–300 car.).<br>• **Avis (`ReviewBottomSheet`)** : Note 1–5 ★ + commentaire obligatoire (10–300 car.).<br>• **Signalement (`OfferDetailScreen`)** : Précision obligatoire (min. 6 car.) si « Autre motif » est choisi. |
| **5. Cohérence et ergonomie générale** | Barre du bas à 5 onglets montrant l'intégration d'EduLink, mode Création **et** Modification (`PATCH /offers/:id`) dans l'assistant, boîte de dialogue de confirmation avant suppression d'offre (`_confirmDeleteOffer`), retours visuels immédiats (`SnackBar`, compteurs, badges non-lus). |

---

## 6. Points de Branchement avec les Autres Modules

Lorsque nous connecterons le backend NestJS / Firebase en semaines 2 à 4, voici comment les autres modules se relient aux écrans de la Marketplace :

| Liaison | Module Partenaire | Point d'intégration dans nos fichiers Marketplace |
| :--- | :--- | :--- |
| **L1 (Auth & Rôles)** | **Users** | Remplacer `MarketplaceController.currentUserId` et `currentUserRole` par le `UserProvider` et le widget `RoleAware` livrés par le module Users. |
| **L2 (Badges)** | **Users** | Appeler `BadgesService.checkAndGrant()` lors d'une 1re vente (`Vendeur`), de 5 cours particuliers terminés (`Mentor`), et d'une note ≥ 4.5 sur 10 avis (`Bien noté`). |
| **L6 (Cours <-> Offres)** | **Cours** | Champ `Offer.courseId` dans `OfferWizardScreen` (Étape 5) alimenté par `CoursesService.getOwned()` / `EnrollmentsService.getSubjects()`, et exposition de `OffersService.listByCourse(courseId)` pour la page d'un cours. |
| **L7 (Forum -> Offres)** | **Forum** | Le bouton *« Trouver une ressource ou un tuteur »* dans le détail d'une question du forum pourra ouvrir `MarketplaceScreen` pré-filtré sur la matière (`_filterSubject`) ou appeler `OffersService.suggestForTags(tags, subject)`. |
| **L8 (Notifications FCM)** | **Évaluations** | Appeler `NotificationsService.send()` lors de `createOrder()` (demande reçue), `updateOrderStatus()` (cours confirmé) et `sendMessage()` (nouveau message). |
| **L9 (Profil Public)** | **Users** | Exposer `OffersService.listBySeller(userId)` et `ReviewsService.getSummary(userId)` pour afficher les offres et la note moyenne d'un vendeur sur son profil public. |
| **L10 (Médias Cloudinary)** | **Cours** | Brancher les boutons d'upload de photos/PDF dans `OfferWizardScreen` (Étape 2) et de pièces jointes dans `OrderChatScreen` sur `MediaService.upload(file, folder)`. |

---

## 6. Comment Lancer et Tester le Projet

1. **Vérifier la version de Flutter** (le `pubspec.yaml` requiert Dart `^3.13.5` / Flutter `3.47.8+`) :
   ```bash
   flutter --version
   flutter pub get
   ```
2. **Lancer sur un émulateur Android (ex. Pixel 9 Pro XL) ou Windows** :
   ```bash
   flutter run
   ```
3. **Tester tous les rôles en direct** :
   - Utilisez la puce **`Rôle: Étudiant` / `Rôle: Enseignant`** en haut à droite de l'`AppBar` pour basculer entre un vendeur étudiant (**« Offre étudiant »**) et un enseignant (**« Enseignant vérifié »**).
