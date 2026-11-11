import 'json_helpers.dart';
import 'reaction.dart';

/// Note de 1 à 5 étoiles donnée par un utilisateur à une question ou à une réponse.
/// L'identifiant `targetType_targetId_userId` garantit une seule note par
/// utilisateur et par cible (la modifier remplace la précédente).
class Rating {
  static const int minStars = 1;
  static const int maxStars = 5;

  final ReactionTarget targetType;
  final String targetId;
  final String userId;
  final int stars;

  const Rating({
    required this.targetType,
    required this.targetId,
    required this.userId,
    required this.stars,
  });

  /// Identifiant unique : une note par utilisateur et par cible.
  String get id => '${targetType.name}_${targetId}_$userId';

  Map<String, dynamic> toJson() => {
        'targetType': targetType.name,
        'targetId': targetId,
        'userId': userId,
        'stars': stars,
      };

  factory Rating.fromJson(Map<String, dynamic> json) {
    final raw = (json['stars'] as num?)?.toInt() ?? minStars;
    return Rating(
      targetType: enumFromName(
          ReactionTarget.values, json['targetType'], ReactionTarget.post),
      targetId: (json['targetId'] as String?) ?? '',
      userId: (json['userId'] as String?) ?? '',
      stars: raw.clamp(minStars, maxStars),
    );
  }
}
