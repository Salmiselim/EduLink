# Module Évaluations — Audit Complet, Correctifs, Analyse des APIs & Guide de Test

> **Branche** : `cours`  
> **Périmètre** : Module Évaluations (`lib/features/evaluations/`) et intégration inter-modules (`lib/main.dart`, `lib/features/auth/`, `lib/features/courses/`).

---

## 1. Correctifs des Problèmes Signalés

### 1.1 Mode Enseignant — Fuite et partage de données entre utilisateurs (Critique)

#### Causes racines identifiées
1. **Absence de filtre propriétaire dans Firestore (`EvaluationsFirestoreService`)** :
   - `getQuizzes()`, `getAssignments()` et `getDocuments()` retournaient **tous** les documents de la collection sans filtrer par `teacherId == _cachedUid` lorsque l'utilisateur connecté était un enseignant.
2. **Mauvaise liaison de cours dans `EvaluationsController.connectCloud()`** :
   - Le contrôleur peuplait `_courses` avec `CoursesController.instance.publishedCourses` (tous les cours publiés de **tous** les enseignants) au lieu de `CoursesController.instance.teacherCourses` (uniquement les cours de l'enseignant connecté).
3. **Écrasement des cours d'autrui lors de la connexion d'un nouvel enseignant (`CoursesCloudController.connectCloud()`)** :
   - Lorsqu'un second enseignant sans cours se connectait, `seedDemoCourses()` itérait sur `_courses` (qui contenait les cours publiés du premier enseignant) et réécrivait `teacherId: user.uid` sur tous les cours existants dans Firestore.
4. **Absence de purge de session et de cache Hive à la déconnexion** :
   - Se déconnecter puis se reconnecter avec un autre compte conservait en mémoire les listes `quizzes`, `assignments`, `documents`, `submissions`, `attempts` et `gradebookRows` du compte précédent, ainsi que la clé Hive globale `quiz_list` partagée entre tous les comptes.
5. **Condition de course au démarrage (`_initRepository` vs `connectCloud`)** :
   - `connectCloud()` s'exécutait avant la fin de `_initRepository()` (`_ready == false`), ce qui sautait la mise à jour de `_repo.currentUserId` et le rechargement `loadAll()`.

#### Correctifs appliqués
- **Filtrage strict par `teacherId` dans Firestore** (`lib/features/evaluations/services/evaluations_firestore_service.dart`) :
  - En mode enseignant, `getQuizzes()`, `getAssignments()` et `getDocuments()` filtrent désormais strictement par `teacherId == _cachedUid`.
  - Toute modification ou suppression (`updateQuiz`, `deleteQuiz`, `updateAssignment`, `deleteAssignment`, `updateDocument`, `deleteDocument`) vérifie que `doc['teacherId'] == _cachedUid` avant d'agir.
- **Isolation côté contrôleur et UI** (`lib/features/evaluations/controllers/evaluations_controller.dart`, `evaluations_screen.dart`) :
  - Ajout de `teacherQuizzes` et `teacherAssignments` filtrés sur `teacherId == currentUserId`.
  - `visibleDocuments()` filtre par `d.teacherId == currentUserId` en mode enseignant.
  - `copiesToGrade()` ne retourne que les copies rattachées aux devoirs de l'enseignant connecté.
  - `_syncCoursesFromModule()` lie uniquement `teacherCourses` pour un enseignant et `enrolledCourses` pour un étudiant.
- **Purge complète à la déconnexion et isolation du cache Hive** (`auth_service.dart`, `main.dart`, `evaluations_local_service.dart`) :
  - Ajout du hook `AuthService.onSignedOut` qui déclenche `CoursesController.instance.resetSession()` et `EvaluationsController.instance.resetSession()`.
  - La clé du cache Hive des quiz est désormais préfixée par l'identifiant utilisateur (`quiz_list_$userId`).
- **Protection de `seedDemoCourses()`** (`lib/features/courses/data/courses_mock_data.dart`) :
  - Ne s'exécute que si Firestore est totalement vide et refuse d'écraser tout cours appartenant déjà à un autre enseignant.

---

### 1.2 Mode Enseignant — La suppression ne fonctionnait pas (Quiz, Devoirs, Documents)

#### Causes racines identifiées
1. **Règle de sécurité Firestore incompatible avec `.delete()`** :
   - Dans `firestore.rules`, les collections `quizzes`, `assignments` et `documents` utilisent :
     ```
     allow write: if isTeacher() && request.resource.data.teacherId == request.auth.uid;
     ```
   - Or, dans les règles Firestore, lors d'une opération `delete`, `request.resource` vaut **`null`**. L'évaluation de `request.resource.data.teacherId` provoque donc systématiquement une erreur `permission-denied` sur `.delete()`.
2. **Ordre de suppression parent / enfants inversé** :
   - `deleteQuiz` et `deleteAssignment` tentaient de supprimer le document parent **avant** de supprimer les `quiz_attempts` et `submissions` enfants. Or, la règle de suppression des enfants vérifie `get(.../quizzes/$(resource.data.quizId)).data.teacherId == request.auth.uid` — ce qui échoue si le parent n'existe plus.
3. **Désynchronisation des identifiants à la création (`upsertAssignment`, `upsertDocument`, `upsertQuiz`)** :
   - Les assistants créaient un objet local avec un ID (ex. `asg_1731...`), mais `_assignmentToBody` / `_documentToBody` n'envoyaient pas `id` au service Firestore, qui générait un nouvel ID (`assign_1731...`). De plus, `upsertAssignment` et `upsertDocument` ignoraient l'objet retourné par Firestore. Toute suppression ultérieure ciblait donc un ID inexistant dans Firestore.
4. **Absence de bouton de suppression directe sur la liste des documents** :
   - Les cartes de l'onglet « Documents » n'affichaient aucun bouton de suppression ni d'édition directe.

#### Correctifs appliqués
- **Suppression hybride (Hard Delete + Soft Delete `isDeleted: true` de repli)** (`evaluations_firestore_service.dart`) :
  - Les enfants (`quiz_attempts` / `submissions`) sont supprimés **en premier** pendant que le parent existe encore.
  - Le service tente `.delete()` sur le parent ; si les règles Firestore distantes rejettent `.delete()` à cause de `request.resource == null`, il effectue immédiatement un `.update({'isDeleted': true, 'teacherId': _cachedUid})` (qui satisfait `request.resource.data.teacherId == request.auth.uid`).
  - Toutes les lectures (`getQuizzes`, `getAssignments`, `getDocuments`, `getGradebook`, `getUpcoming`) excluent les documents marqués `isDeleted == true`.
- **Préservation de l'ID de bout en bout** (`evaluations_controller.dart`, `evaluations_firestore_service.dart`) :
  - `_quizToBody`, `_assignmentToBody` et `_documentToBody` incluent désormais `'id'`.
  - `createQuiz`, `createAssignment` et `createDocument` réutilisent cet ID comme identifiant de document Firestore.
  - `deleteQuiz`, `deleteAssignment` et `deleteDocument` mettent à jour l'interface de manière optimiste immédiatement et restaurent l'état en cas d'erreur.
- **Boutons Modifier / Supprimer sur chaque document** (`evaluations_screen.dart`, `document_detail_screen.dart`) :
  - Ajout des boutons d'édition et de suppression avec confirmation directement sur chaque ligne de l'onglet « Documents » ainsi que dans l'écran de détail.

---

### 1.3 Mode Étudiant — Visibilité de tous les devoirs au lieu des seuls cours inscrits

#### Causes racines identifiées
1. `EvaluationsFirestoreService.getAssignments()`, `getQuizzes()`, `getDocuments()` et `getUpcoming()` ne filtraient pas les résultats selon la collection `enrollments` de l'étudiant connecté.
2. `EvaluationsController.studentAssignments` et `assignmentsForStudent()` retournaient la liste brute `assignments` sans vérifier `CoursesController.instance.myEnrollments`.

#### Correctifs appliqués
- **Filtrage dans Firestore (`_enrolledCourseIds()`)** (`evaluations_firestore_service.dart`) :
  - Pour tout utilisateur non-enseignant, le service récupère d'abord les `courseId` inscrits dans `enrollments` (`where('studentId', isEqualTo: _cachedUid)`).
  - Si l'étudiant n'est inscrit à aucun cours, `getQuizzes()`, `getAssignments()`, `getDocuments()` et `getUpcoming()` retournent immédiatement une liste vide `[]`.
  - Sinon, seuls les quiz publiés, devoirs et documents dont le `courseId` appartient aux cours inscrits sont retournés.
- **Filtrage réactif dans `EvaluationsController`** (`evaluations_controller.dart`) :
  - `studentQuizzes` / `publishedQuizzesForStudent()`, `studentAssignments` / `assignmentsForStudent()` et `visibleDocuments()` filtrent systématiquement par les cours inscrits de l'étudiant (`_enrolledCourseIds`).
  - Un écouteur sur `CoursesController.instance` (`_onCoursesUpdated`) recharge automatiquement les évaluations dès qu'un étudiant s'inscrit ou se désinscrit d'un cours.

---

## 2. Autres Problèmes Cachés Découverts et Corrigés

Lors de l'audit complet du module, **7 bugs supplémentaires** (que vous n'aviez peut-être pas encore rencontrés) ont été identifiés et corrigés :

1. **Crash `RangeError` dans `getVisibleAttempts()` et `getVisibleSubmissions()`** (`evaluations_firestore_service.dart`) :
   - **Bug** : Le découpage par lots de 10 utilisait `ids.sublist(i, i + 10)` sans borner la fin à `ids.length`. Dès qu'un enseignant avait entre 1 et 9 quiz ou devoirs, `sublist(0, 10)` levait un `RangeError` silencieux ou bloquant, empêchant le chargement des copies à corriger et des tentatives !
   - **Correctif** : Remplacé par `ids.skip(i).take(10).toList()`.
2. **Carnet de notes étudiant toujours vide à cause d'un `permission-denied` Firestore** (`evaluations_firestore_service.dart`) :
   - **Bug** : `getGradebook(courseId)` exécutait `_attempts.where('quizId', isEqualTo: q.id)` sans `.where('studentId', isEqualTo: _cachedUid)` lorsqu'un étudiant consultait ses notes. Comme les règles Firestore de `quiz_attempts` et `submissions` exigent `resource.data.studentId == request.auth.uid` pour les étudiants, Firestore rejetait toute la requête.
   - **Correctif** : Ajout du filtre `.where('studentId', isEqualTo: _cachedUid)` pour les étudiants dans `getGradebook()`.
3. **Statistiques et notes de quiz invisibles côté enseignant à cause des règles `quiz_attempts`** (`evaluations_firestore_service.dart`) :
   - **Bug** : Dans `firestore.rules`, `quiz_attempts` avait `allow read: if isSignedIn() && resource.data.studentId == request.auth.uid;` (contrairement à `submissions` qui autorise `|| isTeacher()`). Un enseignant lisant `quiz_attempts` recevait donc `permission-denied`.
   - **Correctif** : Lors de `submitAttempt`, une copie miroir (`recordType: 'quiz_attempt'`) est enregistrée dans `submissions` (lisible par les enseignants), et les méthodes `getQuizResults`, `getVisibleAttempts` et `getGradebook` basculent automatiquement sur ce miroir si la lecture directe de `quiz_attempts` est refusée aux enseignants.
4. **Statut du carnet de notes mal affiché (`'graded'` / `'pending'` en orange)** (`evaluations_screen.dart`) :
   - **Bug** : `EvaluationsFirestoreService.getGradebook()` renvoyait `status: 'graded'` ou `'pending'`, alors que `EvaluationsScreen._gradebook()` testait `r.status == 'Noté'`. Résultat : même une copie corrigée s'affichait avec le texte brut `graded` en couleur d'alerte orange (`EduColors.warning`).
   - **Correctif** : Normalisation dans `_gradebook()` : `'graded'` / `'Noté'` → badge vert `Noté` (`EduColors.success`), `'pending'` → badge orange `En attente`.
5. **Commentaire de correction (`feedback`) invisible pour l'étudiant et bouton « Modifier le dépôt » trompeur** (`evaluations_screen.dart`) :
   - **Bug** : Une fois un devoir déposé, le bouton affichait « Modifier le dépôt » tout en étant grisé/désactivé, et le commentaire (`sub.feedback`) saisi par l'enseignant lors de la correction n'était affiché nulle part sur la carte du devoir.
   - **Correctif** : Affichage d'un encadré « Commentaire enseignant : … » sur la carte du devoir dès qu'il est corrigé, et libellé explicite du bouton (`Déposer`, `Déjà déposé`, `Copie corrigée`).
6. **Bascule de rôle simulé visible même connecté à Firebase** (`lib/main.dart`) :
   - **Bug** : Contrairement aux onglets Cours et Marketplace qui masquaient le bouton `Rôle: Étudiant / Enseignant` derrière `if (controller.isDemoMode)`, `EvaluationsRoot` l'affichait en permanence.
   - **Correctif** : Ajout de la garde `if (controller.isDemoMode)` dans `EvaluationsRoot`.
7. **Crash `DropdownButtonFormField` lors d'un changement de compte avec filtre de cours actif** (`evaluations_screen.dart`) :
   - **Bug** : Si un utilisateur sélectionnait un cours dans le menu déroulant des Notes ou Documents puis changeait de compte, `_courseFilter` pointait vers un ID absent de `accessibleCourses`, provoquant une erreur d'assertion Flutter.
   - **Correctif** : Validation `safeCourseFilter` vérifiant que `_courseFilter` appartient bien à `accessibleCourses`.

---

## 3. Les APIs du Module sont-elles Gratuites ou Nécessitent-elles des Alternatives ?

Toutes les APIs et briques techniques utilisées dans le module Évaluations sont **100 % gratuites** et disposent déjà de mécanismes de repli intégrés. **Aucune carte bancaire ni alternative payante n'est requise.**

| Service / API | Usage dans le module | Coût & Quotas | Repli / Alternative intégrée |
| :--- | :--- | :--- | :--- |
| **Google Gemini API** (`generativelanguage.googleapis.com`) | Génération automatique de brouillons de QCM dans `QuizWizardScreen` (`EvaluationsAiService`) | **100 % Gratuit** via Google AI Studio (plan gratuit sans carte bancaire : ~15 requêtes/min, 1 500 requêtes/jour). | Cascade multi-modèles (`gemini-3.5-flash` → `gemini-3.5-flash-lite` → `gemini-3.1-flash-lite` → `gemini-2.5-flash` → `gemini-2.0-flash`) + **générateur local hors-ligne** (`generateGeminiQuestions`) si clé absente ou quota atteint. |
| **Firebase Authentication & Cloud Firestore** | Authentification, rôles (`users`), stockage temps réel (`quizzes`, `assignments`, `submissions`, `documents`) | **100 % Gratuit** sur le plan **Firebase Spark** (50 000 lectures/jour, 20 000 écritures/jour, 20 000 suppressions/jour, 1 GiB stockage). | **Mode démonstration + Cache local Hive** (`EvaluationsLocalService`) si hors-ligne ou sans Firebase. |
| **Stockage de fichiers PDF** (`attachments`, `fileUrls`, `fileUrl`) | Consignes de devoirs, dépôts étudiants et documents de cours | **100 % Gratuit** : les fichiers utilisent des **chemins/métadonnées simulés** en base Firestore au lieu de Firebase Cloud Storage (qui nécessite le plan payant Blaze depuis 2024). | Conserver ce mode par métadonnées pour la démo, ou utiliser **Supabase Storage** (1 Go gratuit sans CB) / **Cloudinary** si un hébergement binaire réel est souhaité plus tard. |
| **API REST NestJS** (`EvaluationsApiService`, `10.0.2.2:3000`) | Client HTTP Dio historique | **Inutilisé en mode Firebase** (aucun serveur à payer). | Conservé uniquement comme doublure d'interface pour les tests unitaires. |

### Configuration optionnelle de la clé Gemini (2 minutes)
1. Créer une clé gratuite sur [https://aistudio.google.com](https://aistudio.google.com) (**Get API key**).
2. La placer dans le fichier `.env` à la racine du projet :
   ```env
   GEMINI_API_KEY=AIzaSy...
   ```
3. Même sans cette clé, le bouton **« Générer un brouillon »** fonctionne immédiatement grâce au générateur local intégré.

---

## 4. Guide Complet de Test (Automatisé & Manuel)

### 4.1 Lancer les tests automatisés

Dans un terminal à la racine du projet (`c:\Users\jeljl\Desktop\EduLink`), exécutez :

```powershell
flutter analyze
flutter test test/evaluations_metiers_test.dart
```

La suite `test/evaluations_metiers_test.dart` valide **8 scénarios critiques** :
1. Rechargement des tentatives et des copies après redémarrage (`loadAll`).
2. Publication explicite d'un quiz depuis l'assistant sans bascule involontaire en brouillon.
3. Bouton Publier / Masquer sur les cartes enseignant.
4. Filtrage du carnet de notes par identifiant de cours (`courseId`) et export CSV par identifiant étudiant (`studentId`).
5. Repli automatique du générateur de quiz IA lorsque aucune clé Gemini n'est configurée.
6. **Isolation enseignant** : l'enseignant A (`tch_alice`) ne voit jamais les quiz, devoirs, documents ni copies à corriger de l'enseignant B (`tch_bob`).
7. **Filtrage étudiant par cours inscrits** : un étudiant inscrit uniquement à `course_algo_1` ne voit que les quiz publiés, devoirs et documents de `course_algo_1` (ceux de `course_reseau_1` sont masqués).
8. **Suppression enseignant de bout en bout** : `deleteQuiz`, `deleteAssignment` et `deleteDocument` suppriment immédiatement les éléments créés via `upsertQuiz`, `upsertAssignment` et `upsertDocument`.

---

### 4.2 Scénarios de test manuel dans l'application

#### Scénario A — Isolation des données entre deux enseignants (Teacher Mode)
1. **Connectez-vous avec un compte Enseignant 1** (ou inscrivez un nouveau compte avec le rôle *Enseignant*).
2. Dans l'onglet **Cours**, créez et publiez un cours (ex. *« Architecture Logicielle »*).
3. Allez dans l'onglet **Évaluations** :
   - Cliquez sur **« + Nouvelle évaluation »** → **Quiz** : créez et publiez *« Quiz Archi 1 »*.
   - Cliquez sur **« + Nouvelle évaluation »** → **Devoir** : créez *« TP Archi 1 »* (ajoutez un PDF simulé).
   - Cliquez sur **« + Nouvelle évaluation »** → **Document** : ajoutez *« Polycopié Archi »*.
4. Allez dans l'onglet **Profil** → cliquez sur **« Se déconnecter »**.
5. **Connectez-vous avec un compte Enseignant 2** :
   - Allez dans l'onglet **Évaluations** → vérifiez que **Mes évaluations**, **Copies** et **Documents** sont **totalement vides** (aucun accès aux quiz, devoirs, documents ou cours de l'Enseignant 1).
   - Vérifiez également dans l'onglet **Cours** → **Mes cours** que les cours de l'Enseignant 1 n'ont pas été récupérés par l'Enseignant 2.

#### Scénario B — Suppression de Quiz, Devoirs et Documents (Teacher Mode)
1. Connecté en tant qu'**Enseignant 1**, ouvrez l'onglet **Évaluations** :
   - Dans **Mes évaluations**, cliquez sur l'icône corbeille rouge (**Supprimer**) d'un quiz → confirmez → le quiz disparaît immédiatement et un message *« Quiz supprimé. »* s'affiche.
   - Cliquez sur l'icône corbeille rouge (**Supprimer**) d'un devoir → confirmez → le devoir disparaît immédiatement.
   - Ouvrez le sous-onglet **Documents** → cliquez sur l'icône corbeille rouge à droite d'un document (ou ouvrez le document puis cliquez sur la corbeille en haut à droite) → confirmez → le document disparaît immédiatement.
2. **Test de persistance** : faites glisser la liste vers le bas (*pull-to-refresh*) ou redémarrez l'application → vérifiez que les éléments supprimés **ne réapparaissent pas**.

#### Scénario C — Filtrage des devoirs et quiz par cours inscrits (Student Mode)
1. **Connectez-vous avec un compte Étudiant**.
2. Allez dans l'onglet **Cours** → **Mes cours** et notez les cours auxquels l'étudiant est inscrit (ex. uniquement *« Algorithmique »*, et **pas** *« Architecture Logicielle »*).
3. Allez dans l'onglet **Évaluations** :
   - Dans **À faire**, vérifiez que **seuls** les quiz publiés et les devoirs du cours *« Algorithmique »* apparaissent. Les devoirs des cours auxquels l'étudiant n'est pas inscrit sont **invisibles**.
   - Dans **Documents**, vérifiez que seuls les documents des cours inscrits apparaissent.
4. Retournez dans l'onglet **Cours** → **Catalogue**, inscrivez-vous au cours *« Architecture Logicielle »*, puis revenez dans **Évaluations** :
   - Les quiz, devoirs et documents de *« Architecture Logicielle »* apparaissent désormais automatiquement sans même redémarrer l'application !

#### Scénario D — Flux complet Étudiant ↔ Enseignant (Remise, Correction & Carnet de notes)
1. **Côté Étudiant** (inscrit au cours) :
   - Passez un quiz dans **À faire** → validez → vérifiez la note sur 20 et l'apparition immédiate de la ligne dans l'onglet **Notes** avec le badge vert **Noté**.
   - Sur un devoir, cliquez sur **« Déposer »**, joignez un PDF simulé, saisissez un commentaire d'au moins 10 caractères et validez. Le bouton passe à **« Déjà déposé »** et la ligne apparaît dans **Notes** avec le badge **En attente**.
2. **Côté Enseignant** (propriétaire du cours) :
   - Ouvrez **Évaluations** → **Copies** : la copie de l'étudiant apparaît dans **Copies à corriger**.
   - Cliquez dessus, attribuez une note (ex. `17`) et un commentaire (ex. `Très bon travail sur l'architecture.`), puis enregistrez.
3. **Retour côté Étudiant** :
   - Dans **À faire**, la carte du devoir affiche `17 / 20`, le badge **Copie corrigée** et l'encadré **« Commentaire enseignant : Très bon travail sur l'architecture. »**.
   - Dans **Notes**, la ligne affiche `17 / 20` avec le badge vert **Noté** et peut être exportée en CSV.
