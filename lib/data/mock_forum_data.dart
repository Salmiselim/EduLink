import '../features/forum/models/answer.dart';
import '../features/forum/models/post.dart';
import '../models/rating.dart';
import '../models/reaction.dart';

/// Fournit les données initiales en mémoire utilisées par `ForumProvider`
/// au premier lancement (cours disponibles, questions, réponses et réactions
/// d'exemple). Ensuite, les données sont lues depuis le stockage local.
class MockForumData {
  /// Liste des cours proposés dans les filtres du fil (`ForumFeedScreen`) et lors
  /// de la création d'une question (`AskQuestionScreen`).
  static final List<String> coursesList = [
    'Tous les cours',
    'Développement Mobile (Flutter)',
    'Algorithmique & Complexité',
    'Bases de Données (MongoDB)',
    'Architecture Logicielle',
  ];

  /// Génère la collection initiale de questions (`Post`) avec des horodatages relatifs.
  static List<Post> getInitialPosts() {
    return [
      Post(
        id: 'post_1',
        authorId: 'user_yassine',
        authorName: 'Yassine Karray',
        authorRole: 'student',
        courseName: 'Développement Mobile (Flutter)',
        title: 'Comment bien organiser les dossiers dans un projet Flutter ?',
        body:
            'Bonjour, pour notre projet EduLink, quelle est la structure recommandée pour séparer les écrans, les providers et les modèles ?',
        tags: ['flutter', 'architecture', 'provider'],
        answersCount: 2,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Post(
        id: 'post_2',
        authorId: 'user_sarah',
        authorName: 'Dr. Sarah Mansour',
        authorRole: 'teacher',
        courseName: 'Algorithmique & Complexité',
        title: 'Rappel : Début des séances de révision la semaine prochaine',
        body:
            'N\'hésitez pas à poser vos questions sur le tri rapide et les arbres binaires ici avant la première séance.',
        tags: ['révision', 'annonce'],
        answersCount: 1,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      Post(
        id: 'post_3',
        authorId: 'user_amine',
        authorName: 'Amine Trabelsi',
        authorRole: 'student',
        courseName: 'Bases de Données (MongoDB)',
        title: 'Quelle différence entre find() et findOne() dans Mongoose ?',
        body:
            'Je débute avec MongoDB et Mongoose, est-ce que find() renvoie toujours un tableau même s\'il n\'y a qu\'un seul document ?',
        tags: ['mongodb', 'mongoose'],
        answersCount: 0,
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      Post(
        id: 'post_4',
        authorId: 'user_nour',
        authorName: 'Nour Ben Ali',
        authorRole: 'student',
        courseName: 'Algorithmique & Complexité',
        title: 'Pourquoi mon tri à bulles est-il si lent sur de grands tableaux ?',
        body:
            'Mon tri fonctionne mais devient très lent dès que le tableau dépasse quelques milliers d\'éléments. Voici mon code, qu\'est-ce que je peux améliorer ?',
        tags: ['algorithmique', 'python', 'tri'],
        codeLanguage: 'python',
        codeSnippet: r'''def bubble_sort(values):
    n = len(values)
    for i in range(n):
        for j in range(0, n - i - 1):
            if values[j] > values[j + 1]:
                values[j], values[j + 1] = values[j + 1], values[j]
    return values

print(bubble_sort([5, 2, 9, 1, 7]))''',
        answersCount: 1,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ];
  }

  /// Génère les réponses initiales (`Answer`) rattachées aux questions via `postId`.
  static List<Answer> getInitialAnswers() {
    return [
      Answer(
        id: 'ans_1',
        postId: 'post_1',
        authorId: 'user_sarah',
        authorName: 'Dr. Sarah Mansour',
        authorRole: 'teacher',
        body:
            'Il est conseillé de créer un dossier models/ pour vos classes de données, screens/ pour vos pages, et providers/ pour la gestion d\'état.',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      Answer(
        id: 'ans_2',
        postId: 'post_1',
        authorId: 'user_nour',
        authorName: 'Nour Ben Ali',
        authorRole: 'student',
        body:
            'Personnellement j\'ajoute aussi un dossier widgets/ pour les composants réutilisables comme les cartes.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
      ),
      Answer(
        id: 'ans_3',
        postId: 'post_2',
        authorId: 'user_selim',
        authorName: 'Selim Riahi',
        authorRole: 'student',
        body: 'Merci Madame, est-ce que la séance sera enregistrée ?',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      Answer(
        id: 'ans_4',
        postId: 'post_4',
        authorId: 'user_sarah',
        authorName: 'Dr. Sarah Mansour',
        authorRole: 'teacher',
        body:
            'Votre tri est correct mais en O(n²). Pour de grands tableaux, préférez un tri rapide (O(n log n) en moyenne) :',
        codeLanguage: 'python',
        codeSnippet: r'''def quick_sort(values):
    if len(values) <= 1:
        return values
    pivot = values[len(values) // 2]
    left = [x for x in values if x < pivot]
    middle = [x for x in values if x == pivot]
    right = [x for x in values if x > pivot]
    return quick_sort(left) + middle + quick_sort(right)

print(quick_sort([5, 2, 9, 1, 7]))''',
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
    ];
  }

  /// Réactions initiales (une par utilisateur et par cible).
  static List<Reaction> getInitialReactions() {
    Reaction r(ReactionTarget target, String id, String user, ReactionType type) {
      return Reaction(targetType: target, targetId: id, userId: user, type: type);
    }

    return [
      r(ReactionTarget.reply, 'ans_1', 'user_selim', ReactionType.helpful),
      r(ReactionTarget.reply, 'ans_1', 'user_yassine', ReactionType.helpful),
      r(ReactionTarget.reply, 'ans_1', 'user_nour', ReactionType.like),
      r(ReactionTarget.reply, 'ans_1', 'user_amine', ReactionType.like),
      r(ReactionTarget.reply, 'ans_1', 'user_lina', ReactionType.insightful),
      r(ReactionTarget.reply, 'ans_2', 'user_yassine', ReactionType.like),
      r(ReactionTarget.reply, 'ans_2', 'user_sarah', ReactionType.helpful),
      r(ReactionTarget.reply, 'ans_3', 'user_nour', ReactionType.like),
      r(ReactionTarget.reply, 'ans_4', 'user_nour', ReactionType.helpful),
      r(ReactionTarget.post, 'post_1', 'user_nour', ReactionType.like),
      r(ReactionTarget.post, 'post_1', 'user_amine', ReactionType.insightful),
      r(ReactionTarget.post, 'post_4', 'user_selim', ReactionType.like),
    ];
  }

  /// Notes initiales (1 à 5 étoiles, une par utilisateur et par cible).
  static List<Rating> getInitialRatings() {
    Rating n(ReactionTarget target, String id, String user, int stars) {
      return Rating(targetType: target, targetId: id, userId: user, stars: stars);
    }

    return [
      n(ReactionTarget.reply, 'ans_1', 'user_yassine', 5),
      n(ReactionTarget.reply, 'ans_1', 'user_nour', 5),
      n(ReactionTarget.reply, 'ans_1', 'user_amine', 4),
      n(ReactionTarget.reply, 'ans_1', 'user_lina', 5),
      n(ReactionTarget.reply, 'ans_2', 'user_yassine', 4),
      n(ReactionTarget.reply, 'ans_2', 'user_sarah', 4),
      n(ReactionTarget.reply, 'ans_4', 'user_nour', 5),
      n(ReactionTarget.post, 'post_1', 'user_nour', 4),
      n(ReactionTarget.post, 'post_1', 'user_amine', 5),
      n(ReactionTarget.post, 'post_3', 'user_sarah', 3),
    ];
  }
}
