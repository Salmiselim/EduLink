/// Formate une date en durée relative lisible (« À l'instant », « Il y a 5 min »...).
String formatTimeAgo(DateTime dateTime, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(dateTime);
  if (diff.isNegative || diff.inMinutes < 1) return "À l'instant";
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
  return 'Il y a ${diff.inDays} j';
}
