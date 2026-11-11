# Forum (M3) — liaison Firebase

## Fonctionnement
| Situation | Données du Forum | Identité |
|---|---|---|
| Compte Firebase connecté | Cloud Firestore, temps réel (cache hors-ligne du SDK) | `uid`, nom et rôle lus dans `users/{uid}` |
| Pas de compte (« Passer ») ou Firebase absent | SharedPreferences (JSON) + données d'exemple | Profil simulé, bascule Étudiant / Enseignant |

- `ForumFirebaseLink` écoute `FirebaseAuth.authStateChanges()` : connexion → `ForumProvider.connectRemote`,
  déconnexion → `disconnectRemote` (retour aux données locales). Aucun changement dans `AuthService`.
- `ForumFirestoreService` (contrat `ForumRemote`) lit `posts`, `replies`, `reactions` en flux temps réel.
- Écriture optimiste : l'interface change tout de suite, le flux Firestore remet l'état réel du serveur
  (si une règle refuse l'écriture, l'icône cloud du fil passe à l'orange avec le message).
- Exécution de code : Judge0 CE (HTTP), indépendant de Firebase.
- Autres API (Stack Exchange, Gemini, avec clés) : voir `FORUM_API.md`.

## Collections
| Collection | Id | Champs principaux |
|---|---|---|
| `posts` | `post_<µs>_<n>` | authorId, authorName, authorRole, courseName, title, body, tags, codeSnippet, codeLanguage, status (`open`/`resolved`), acceptedReplyId, createdAt, updatedAt |
| `replies` | `ans_<µs>_<n>` | postId, authorId, authorName, authorRole, body, codeSnippet, codeLanguage, isTeacherVerified, verifiedAt, createdAt, updatedAt |
| `reactions` | `<targetType>_<targetId>_<uid>` | targetType (`post`/`reply`), targetId, userId, type (`like`/`helpful`/`insightful`) |

| `ratings` | `<targetType>_<targetId>_<uid>` | targetType (`post`/`reply`), targetId, userId, stars (1 à 5) |

Réactions emoji : `like` 👍, `helpful` ✅, `insightful` 💡, `applause` 👏, `relevant` 🎯 (une par personne et par cible).
Notes : une par personne et par cible, jamais sur son propre contenu (contrôlé dans l'appli). Classement du fil
« Mieux notées » = moyenne bayésienne `(3 × 3,5 + somme) / (3 + nombre de notes)` ; « Populaires » = réactions + 2 × notes + réponses.

Dates en texte ISO 8601. Le nombre de réponses d'une question n'est pas stocké de façon fiable : il est recalculé
dans l'application à partir de `replies`. Aucun index composite n'est nécessaire (tri côté client).

## Règles Firestore (`firestore.rules`, branche `backend`)
Les règles actuelles couvrent le Forum sauf un cas **obligatoire** et un cas **conseillé**.

**Obligatoire** — un enseignant doit pouvoir vérifier la réponse d'un autre (sinon « Marquer comme vérifiée » est refusé) :

```
match /replies/{replyId} {
  allow read: if isSignedIn();
  allow create: if isSignedIn() && request.resource.data.authorId == request.auth.uid;
  allow update: if isSignedIn() && (
    resource.data.authorId == request.auth.uid
    || (isTeacher()
        && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['isTeacherVerified', 'verifiedAt']))
  );
  allow delete: if isSignedIn() && resource.data.authorId == request.auth.uid;
}
```

**Conseillé** — l'auteur d'une question peut supprimer les réponses qui lui sont rattachées (sinon elles restent
orphelines ; le client les ignore) : ajouter dans la règle `delete` de `replies`
`|| get(/databases/$(database)/documents/posts/$(resource.data.postId)).data.authorId == request.auth.uid`.

**Obligatoire pour les notes** — nouvelle collection `ratings` (à ajouter dans `firestore.rules`, sans elle les notes sont refusées) :

```
match /ratings/{ratingId} {
  allow read: if isSignedIn();
  allow create, update: if isSignedIn()
    && ratingId.split('_')[ratingId.split('_').size() - 1] == request.auth.uid
    && request.resource.data.userId == request.auth.uid
    && request.resource.data.stars is int
    && request.resource.data.stars >= 1 && request.resource.data.stars <= 5;
  allow delete: if isSignedIn()
    && ratingId.split('_')[ratingId.split('_').size() - 1] == request.auth.uid;
}
```

Déploiement : `firebase deploy --only firestore:rules` (ou coller les règles dans la console Firebase → Firestore → Règles → Publier).

## Liens avec les autres modules
- **Auth / Profil** : identité et rôle (`users/{uid}`), mise à jour en direct si le rôle change.
- **Cours** : liste des cours = cours publiés (`CoursesController`) ; le bouton « Poser une question (forum du cours) »
  de la fiche d'un cours ouvre le formulaire avec ce cours présélectionné (`ForumAskArgs`).
- **Marketplace** : « Trouver une ressource ou un tuteur » propose des offres selon la matière du cours
  (`Course.subject`) et les tags de la question.
- **Badges** : `nightlyBadgeCheck` a un TODO « réponses utiles » ; métrique possible =
  nombre de `replies` de l'utilisateur avec `isTeacherVerified == true` ou acceptées (`posts.acceptedReplyId`).
