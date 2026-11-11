/// Calculs liés aux notes (étoiles) du Forum.

/// Note moyenne « a priori » et poids de cette moyenne (équivalent de 3 notes
/// fictives à 3,5 étoiles) utilisés pour le classement.
const double kRatingPriorMean = 3.5;
const int kRatingPriorWeight = 3;

/// Totaux des notes d'une cible : nombre de notes et somme des étoiles.
class RatingStats {
  final int count;
  final int sum;

  const RatingStats(this.count, this.sum);

  static const RatingStats empty = RatingStats(0, 0);

  /// Moyenne simple affichée à l'utilisateur (0 s'il n'y a aucune note).
  double get average => count == 0 ? 0 : sum / count;

  /// Score de classement : moyenne bayésienne. Une seule note à 5 étoiles ne
  /// dépasse pas une question notée 4,8 par vingt personnes.
  double get score => bayesianScore(sum, count);

  RatingStats add(int stars) => RatingStats(count + 1, sum + stars);
}

/// `(poids × moyenne a priori + somme des étoiles) / (poids + nombre de notes)`.
double bayesianScore(int sum, int count) {
  return (kRatingPriorWeight * kRatingPriorMean + sum) /
      (kRatingPriorWeight + count);
}
