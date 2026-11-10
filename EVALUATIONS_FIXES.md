# Évaluations — corrections et guide de l'API gratuite

> Document de suivi pour l'équipe. Ce qui a été corrigé dans le module
> Évaluations, pourquoi, et comment configurer la seule API externe utilisée
> (gratuite). Dernière mise à jour : novembre 2026, branche `cours`.

---

## 1. API externe : Gemini (gratuit) pour le brouillon de quiz

Le bouton **« Générer un brouillon »** de l'assistant de quiz appelle
désormais la **vraie** API Google AI (modèle `gemini-3.5-flash`) au lieu du
générateur local simulé. Le plan utilisé est le **plan gratuit d'AI
Studio** : aucune facturation, aucune carte bancaire.

### Comment obtenir la clé (2 minutes)

1. Ouvrir **https://aistudio.google.com** et se connecter avec un compte
   Google.
2. Cliquer sur **« Get API key »** (bouton en haut à gauche) puis
   **« Create API key »**.
3. Choisir le projet Firebase existant (`edulink-57f43`) ou laisser
   « Create in new project » — peu importe.
4. **Copier la clé** affichée (elle commence par `AIza…`).
5. Ouvrir le fichier **`.env`** à la racine du projet et coller la clé :
   ```
   GEMINI_API_KEY=AIza...
   ```
6. **Ne pas commit la clé** : exécuter une seule fois
   ```
   git update-index --skip-worktree .env
   ```
   à partir de là, git ignore vos modifications locales de ce fichier.

La clé est **partagée avec le module Cours** (même fichier `.env`, même
mécanisme) : une seule configuration pour toute l'application.

### Ce qui se passe sans clé ou en cas de panne

Le service retombe automatiquement sur le **générateur local de
démonstration** (3 questions d'exemple) : l'assistant n'est jamais bloqué,
et un message précise de relire les questions avant publication. L'API est
appelée avec un réessai automatique en cas de pointe de charge (HTTP 503).

### Autres appels réseau du module

- **API REST de secours** (`EvaluationsApiService`, serveur NestJS local
  `10.0.2.2:3000`) : inutilisée quand Firebase est actif — aucun coût.
- **Firestore / Auth / cache Hive** : plan gratuit Firebase (Spark) — OK.
- Aucune autre API payante dans le module.

---

## 2. Corrections CRUD et métiers

### 2.1 « Publier » sauvegardait le quiz en brouillon (grave)

**Symptôme** : créer un quiz avec « Publier » écrivait `isPublished: true`
dans Firestore, puis l'appel de publication **basculait** l'état → le
document finissait en **brouillon** alors que l'interface affichait
« Publié ». Le quiz n'apparaissait donc jamais chez les étudiants. Même bug
en modification et via le bouton Publier/Masquer des cartes.

**Correctif** : nouvelle méthode `setQuizPublished(quizId, published)`
(positionnement **explicite**) à travers toute la pile (service Firestore,
API REST de secours, repository, contrôleur). `upsertQuiz(publish: true)` ne
re-bascule plus rien ; `publishQuizToggle(quizId, cible)` positionne l'état
demandé. Vérifié par 2 tests.

### 2.2 Tentatives, copies et carnet vides après redémarrage

**Symptôme** : `loadAll()` ne chargeait que quiz, devoirs, documents et
« à venir ». Après un redémarrage : le compteur de tentatives
(`canTakeQuiz`) repartait de zéro (un étudiant pouvait repasser un quiz
épuisé), « Copies à corriger » était vide pour l'enseignant, et le carnet de
notes n'affichait rien (les méthodes `loadGradebook`/`getSubmissions`
n'étaient appelées par **aucun** écran).

**Correctif** :
- `loadAll()` charge maintenant **tentatives** (`getVisibleAttempts` :
  les siennes côté étudiant, celles de ses quiz côté enseignant) et
  **copies** (`getVisibleSubmissions` : idem pour les devoirs) ;
- le **carnet** est agrégé au démarrage sur les cours pertinents uniquement
  (cours possédés côté enseignant, cours suivis côté étudiant).

### 2.3 Filtre du carnet de notes inopérant

**Symptôme** : le menu « Filtrer par cours » transmet un **identifiant**
(`courseId`) que le contrôleur comparait au **titre** stocké dans la ligne
(`r.courseTitle != courseId`) → dès qu'un cours était sélectionné, la liste
se vidait. Même bug dans l'export CSV.

**Correctif** : résolution identifiant → titre via les cours liés
(liaison L4 avec le module Cours), appliquée à la fois au filtre et au CSV.
Au passage, l'export CSV filtrait les étudiants par **nom** alors que
l'écran transmet l'**identifiant** → le CSV étudiant était toujours vide.
Aligné sur `studentId`.

### 2.4 Suppression d'un quiz / devoir impossible (règles)

**Symptôme** : les règles Firestore interdisaient **toute** suppression de
tentatives (`quiz_attempts: delete: if false`) et de copies
(`submissions: delete: if false`) — la cascade de `deleteQuiz` /
`deleteAssignment` échouait donc (permission-denied) après avoir supprimé le
parent.

**Correctif** (deux niveaux) :
- règles déployées : l'**enseignant propriétaire** du quiz/devoir peut
  supprimer les tentatives/copies liées (vérification par `get` du parent) ;
- les cascades côté service suppriment les enfants **individuellement** :
  un échec isolé n'annule plus les autres.

### 2.5 Écrans rouges sur données non chargées

**Symptôme** : `quizById(...)!`, `submissionById(...)!`,
`assignmentById(...)!` appliqués directement dans `initState`/`build` —
crash (« Bad state ») si l'objet n'était pas en mémoire.

**Correctif** : gardes sur les 3 écrans (passage de quiz, correction de
copie, dépôt de devoir) → état vide explicite (« Quiz introuvable »…) + retour
propre au lieu d'un crash.

### 2.6 Suppression de document inaccessible

**Symptôme** : le CRUD document exposait création/édition mais **aucun**
bouton de suppression.

**Correctif** : bouton « Supprimer » (enseignant) dans la fiche document,
avec boîte de confirmation.

### 2.7 Barème des questions incohérent

**Symptôme** : le message demandait « entre 0.5 et 20 » mais le contrôle
rejetait tout `points <= 0` — un point à 0.2 passait avec un message faux.

**Correctif** : contrôle aligné sur le message (`points < 0.5 || points >
20`).

---

## 3. Ce qui reste (connu, volontairement)

- **Badges (L2)** et **notifications FCM (L8)** : stubs (`debugPrint`) — la
  logique est prête côté repository, l'activation attend la décision
  d'équipe (Cloud Functions ou endpoint dédié).
- Le brouillon IA est **assisté** : l'enseignant relit et corrige chaque
  question avant publication (par conception).
- L'API REST de secours (NestJS) n'implémente pas les 3 nouvelles méthodes
  (`getVisibleAttempts`, `getVisibleSubmissions`, `setQuizPublished`) — elle
  renvoie « non supporté » et le module continue de fonctionner (listes
  vides, repli).

## 4. Tests ajoutés

`test/evaluations_metiers_test.dart` — 5 tests sur la logique métier avec
repository injecté (sans Firebase ni réseau) :
1. `loadAll` recharge tentatives + copies (compteurs et « Copies à
   corriger » corrects après redémarrage) ;
2. publication depuis l'assistant sans bascule parasite (2 cas) ;
3. bouton Publier/Masquer positionne l'état demandé ;
4. filtre carnet par identifiant de cours + export CSV par identifiant
   étudiant ;
5. repli IA sans clé configurée.
