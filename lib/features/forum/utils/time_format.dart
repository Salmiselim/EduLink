/// Convertit une date [dateTime] en durée relative concise en français
/// (ex. « À l'instant », « Il y a 5 min », « Il y a 2 h », « Il y a 3 j »).
/// Utilisée par `PostCard`, `AnswerCard` et `QuestionDetailScreen` ; le paramètre
/// optionnel [now] permet de figer l'instant de référence lors des tests unitaires.
String formatTimeAgo(DateTime dateTime, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(dateTime);
  if (diff.isNegative || diff.inMinutes < 1) return "À l'instant";
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
  return 'Il y a ${diff.inDays} j';
}
