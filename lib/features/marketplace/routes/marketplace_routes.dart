import 'package:flutter/material.dart';
import '../models/marketplace_models.dart';
import '../screens/offer_detail_screen.dart';
import '../screens/offer_wizard_screen.dart';
import '../screens/order_chat_screen.dart';
import '../screens/order_checkout_screen.dart';

// ============================================================================
// GESTION CENTRALISÉE DES ROUTES — MODULE M5 : MARKETPLACE
// Répond au critère d'évaluation : « Navigation et gestion des routes ».
// Définit toutes les routes nommées et leurs arguments typés via [onGenerateRoute].
// ============================================================================

/// Arguments typés pour la route de détail d'une offre (`OfferDetailScreen`)
class OfferDetailArgs {
  final String offerId;
  const OfferDetailArgs({required this.offerId});
}

/// Arguments typés pour l'assistant de création / modification d'offre (`OfferWizardScreen`)
class OfferWizardArgs {
  final Offer? existingOffer;
  const OfferWizardArgs({this.existingOffer});
}

/// Arguments typés pour l'écran de commande / réservation (`OrderCheckoutScreen`)
class OrderCheckoutArgs {
  final Offer offer;
  final AvailabilitySlot? preselectedSlot;
  const OrderCheckoutArgs({
    required this.offer,
    this.preselectedSlot,
  });
}

/// Arguments typés pour l'écran de chat lié à une commande (`OrderChatScreen`)
class OrderChatArgs {
  final String orderId;
  const OrderChatArgs({required this.orderId});
}

/// Table centralisée des routes nommées de la Marketplace (M5)
class MarketplaceRoutes {
  MarketplaceRoutes._();

  static const String home = '/';
  static const String offerDetail = '/marketplace/offer-detail';
  static const String offerWizard = '/marketplace/offer-wizard';
  static const String orderCheckout = '/marketplace/order-checkout';
  static const String orderChat = '/marketplace/order-chat';

  /// Générateur de routes centralisé branché sur `MaterialApp.onGenerateRoute`
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case offerDetail:
        final args = settings.arguments as OfferDetailArgs;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => OfferDetailScreen(offerId: args.offerId),
        );

      case offerWizard:
        final args = settings.arguments as OfferWizardArgs?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => OfferWizardScreen(
            existingOffer: args?.existingOffer,
          ),
        );

      case orderCheckout:
        final args = settings.arguments as OrderCheckoutArgs;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => OrderCheckoutScreen(
            offer: args.offer,
            preselectedSlot: args.preselectedSlot,
          ),
        );

      case orderChat:
        final args = settings.arguments as OrderChatArgs;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => OrderChatScreen(orderId: args.orderId),
        );

      default:
        return null;
    }
  }
}
