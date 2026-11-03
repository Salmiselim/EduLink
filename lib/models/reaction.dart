import 'json_helpers.dart';

/// Cible d'une réaction : une question ou une réponse.
enum ReactionTarget { post, reply }

/// Types de réaction proposés par le Forum.
enum ReactionType { like, helpful, insightful }

/// Réaction d'un utilisateur sur une question ou une réponse.
/// L'identifiant `targetType_targetId_userId` garantit une seule réaction
/// par utilisateur et par cible (comme dans la collection Firestore `reactions`).
class Reaction {
  final ReactionTarget targetType;
  final String targetId;
  final String userId;
  final ReactionType type;

  const Reaction({
    required this.targetType,
    required this.targetId,
    required this.userId,
    required this.type,
  });

  /// Identifiant unique : une réaction par utilisateur et par cible.
  String get id => '${targetType.name}_${targetId}_$userId';

  Map<String, dynamic> toJson() => {
        'targetType': targetType.name,
        'targetId': targetId,
        'userId': userId,
        'type': type.name,
      };

  factory Reaction.fromJson(Map<String, dynamic> json) {
    return Reaction(
      targetType: enumFromName(
          ReactionTarget.values, json['targetType'], ReactionTarget.post),
      targetId: (json['targetId'] as String?) ?? '',
      userId: (json['userId'] as String?) ?? '',
      type: enumFromName(ReactionType.values, json['type'], ReactionType.like),
    );
  }
}
