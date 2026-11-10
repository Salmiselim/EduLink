# Forum (M3) — API externes avec clé

Le Forum utilise trois API HTTP, en plus de Cloud Firestore :

| API | Rôle dans le Forum | Clé | Fichiers |
|---|---|---|---|
| **Judge0 CE** | Exécuter un extrait de code (bouton « Exécuter ») | aucune (API publique) | `code_runner_service.dart` |
| **Stack Exchange 2.3** | « Questions similaires sur Stack Overflow » pendant la rédaction d'une question | `STACKEXCHANGE_KEY` (gratuite) | `stack_overflow_service.dart`, `similar_questions_panel.dart` |
| **Gemini** | « Expliquer » un code, ou « Expliquer l'erreur » après une exécution en échec | `GEMINI_API_KEY` (gratuite) | `gemini_service.dart`, `code_block.dart` |

## 1. Obtenir les clés
- **Stack Exchange** : créer une application sur <https://stackapps.com/apps/oauth/register> (champs « OAuth Domain » = `localhost`), puis copier la **Key**. Sans clé l'API répond quand même (300 requêtes/jour par IP) ; avec la clé : 10 000/jour.
- **Gemini** : <https://aistudio.google.com/apikey> → « Create API key ».

## 2. Fournir les clés au lancement (jamais dans le code)
1. Copier `dart_defines.example.json` en `dart_defines.json` (déjà dans `.gitignore`) et remplir les deux clés.
2. Lancer : `flutter run --dart-define-from-file=dart_defines.json`
3. Android Studio : *Run → Edit Configurations → Additional run args* → `--dart-define-from-file=dart_defines.json`.

Option : `GEMINI_MODEL` (défaut `gemini-3.5-flash-lite`) pour changer de modèle sans modifier le code.

Sans clé, l'appli fonctionne : le bouton « Expliquer » affiche « clé API Gemini non configurée », et la recherche Stack Overflow utilise le quota sans clé.

## 3. Fonctionnement
**Stack Exchange** — `GET https://api.stackexchange.com/2.3/search/advanced?q=<titre>&tagged=<langage>&site=stackoverflow&answers=1&pagesize=5&key=<clé>`
- Déclenchée 900 ms après la dernière frappe du titre (12 caractères minimum), uniquement à la création d'une question.
- Le langage du code joint est converti en tag Stack Overflow (`cpp` → `c++`).
- Respecte le champ `backoff` de l'API, met les résultats en cache, décode les entités HTML des titres.
- Stack Overflow est en anglais : les titres en français donnent moins de résultats ; les termes techniques (flutter, provider, setState...) fonctionnent bien.
- Les contenus Stack Overflow sont sous licence CC BY-SA : la source est indiquée sous les résultats.

**Gemini** — `POST https://generativelanguage.googleapis.com/v1beta/models/<modèle>:generateContent` avec l'en-tête `x-goog-api-key`.
- Consigne pédagogique : explique ce que fait le code, l'erreur probable et une piste de correction **sans réécrire la solution**, en français, 150 mots max.
- Le code de l'étudiant est traité comme une donnée (la consigne dit d'ignorer toute instruction qu'il contiendrait).
- Après une exécution Judge0 en échec, la sortie d'erreur est envoyée avec le code.
- L'explication est étiquetée « Généré par IA : à vérifier » : elle ne remplace pas la réponse validée par un enseignant (`isTeacherVerified`).
- Réponses mises en cache pour ne pas consommer le quota deux fois.

## 4. Sécurité
Une clé passée par `--dart-define` est incluse dans l'application compilée : acceptable pour un projet pédagogique, mais pour une vraie mise en production il faudrait passer par un petit serveur (Cloud Functions) qui garde la clé Gemini côté serveur.
