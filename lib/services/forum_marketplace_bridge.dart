import '../features/marketplace/data/marketplace_mock_data.dart';
import '../features/marketplace/models/marketplace_models.dart';

/// Liaison L7 : depuis une question du Forum, propose des offres de la
/// Marketplace (ressources ou cours particuliers) selon la matière et les tags.
/// Lecture seule : le Forum ne modifie jamais les données de la Marketplace.
class ForumMarketplaceBridge {
  const ForumMarketplaceBridge();

  /// Correspondance cours du Forum -> matière de la Marketplace.
  static const Map<String, String> courseToSubject = {
    'Développement Mobile (Flutter)': 'Développement Mobile',
    'Algorithmique & Complexité': 'Algorithmique',
    'Bases de Données (MongoDB)': 'Bases de Données',
    'Architecture Logicielle': 'Génie Logiciel',
  };

  /// Offres publiées triées par pertinence : +3 si la matière correspond,
  /// +1 par tag retrouvé dans le titre ou la description ; note en cas d'égalité.
  List<Offer> suggestFor({
    required String courseName,
    required List<String> tags,
    int limit = 5,
  }) {
    final subject = courseToSubject[courseName];
    final scored = <({Offer offer, int score})>[];

    for (final offer in MarketplaceController.instance.allOffers) {
      if (offer.status != OfferStatus.published) continue;

      var score = 0;
      if (subject != null && offer.subject == subject) score += 3;
      final haystack = '${offer.title} ${offer.description}'.toLowerCase();
      for (final tag in tags) {
        if (tag.isNotEmpty && haystack.contains(tag.toLowerCase())) score += 1;
      }
      if (score > 0) scored.add((offer: offer, score: score));
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.offer.ratingAvg.compareTo(a.offer.ratingAvg);
    });
    return scored.take(limit).map((e) => e.offer).toList();
  }
}
