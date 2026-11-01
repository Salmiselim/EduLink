import '../models/answer.dart';
import '../models/post.dart';

/// Fournit les données initiales en mémoire utilisées par `ForumProvider`
/// au démarrage de l'application (cours disponibles, questions et réponses d'exemple).
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
        authorName: 'Yassine Karray',
        authorRole: 'student',
        courseName: 'Développement Mobile (Flutter)',
        title: 'Comment bien organiser les dossiers dans un projet Flutter ?',
        body:
            'Bonjour, pour notre projet EduLink, quelle est la structure recommandée pour séparer les écrans, les providers et les modèles ?',
        answersCount: 2,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Post(
        id: 'post_2',
        authorName: 'Dr. Sarah Mansour',
        authorRole: 'teacher',
        courseName: 'Algorithmique & Complexité',
        title: 'Rappel : Début des séances de révision la semaine prochaine',
        body:
            'N\'hésitez pas à poser vos questions sur le tri rapide et les arbres binaires ici avant la première séance.',
        answersCount: 1,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      Post(
        id: 'post_3',
        authorName: 'Amine Trabelsi',
        authorRole: 'student',
        courseName: 'Bases de Données (MongoDB)',
        title: 'Quelle différence entre find() et findOne() dans Mongoose ?',
        body:
            'Je débute avec MongoDB et Mongoose, est-ce que find() renvoie toujours un tableau même s\'il n\'y a qu\'un seul document ?',
        answersCount: 0,
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
    ];
  }

  /// Génère les réponses initiales (`Answer`) rattachées aux questions via `postId`.
  static List<Answer> getInitialAnswers() {
    return [
      Answer(
        id: 'ans_1',
        postId: 'post_1',
        authorName: 'Dr. Sarah Mansour',
        authorRole: 'teacher',
        body:
            'Il est conseillé de créer un dossier models/ pour vos classes de données, screens/ pour vos pages, et providers/ pour la gestion d\'état.',
        votesCount: 5,
        isUpvoted: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      Answer(
        id: 'ans_2',
        postId: 'post_1',
        authorName: 'Nour Ben Ali',
        authorRole: 'student',
        body:
            'Personnellement j\'ajoute aussi un dossier widgets/ pour les composants réutilisables comme les cartes.',
        votesCount: 2,
        isUpvoted: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
      ),
      Answer(
        id: 'ans_3',
        postId: 'post_2',
        authorName: 'Selim Riahi',
        authorRole: 'student',
        body: 'Merci Madame, est-ce que la séance sera enregistrée ?',
        votesCount: 1,
        isUpvoted: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    ];
  }
}
