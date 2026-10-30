import 'package:flutter/material.dart';
import '../models/marketplace_models.dart';
import '../screens/offer_detail_screen.dart';
import '../screens/offer_wizard_screen.dart';
import '../screens/order_chat_screen.dart';
import '../screens/order_checkout_screen.dart';

// Gestion centralisée des routes nommées du module Marketplace.
// Regroupe les classes d'arguments fortement typés (*Args) et la fabrique
// [MarketplaceRoutes.onGenerateRoute] enregistrée sur `MaterialApp.onGenerateRoute`.

/// Arguments transmis lors de la navigation vers [OfferDetailScreen].
class OfferDetailArgs {
  final String offerId;
  const OfferDetailArgs({required this.offerId});
}

/// Arguments optionnels transmis à [OfferWizardScreen].
/// Si [existingOffer] est non nul, l'assistant préremplit les champs en mode édition.
class OfferWizardArgs {
  final Offer? existingOffer;
  const OfferWizardArgs({this.existingOffer});
}

/// Arguments requis pour ouvrir [OrderCheckoutScreen] avec l'offre ciblée
/// et un éventuel créneau horaire [preselectedSlot] retenu sur l'écran précédent.
class OrderCheckoutArgs {
  final Offer offer;
  final AvailabilitySlot? preselectedSlot;
  const OrderCheckoutArgs({
    required this.offer,
    this.preselectedSlot,
  });
}

/// Arguments transmis à [OrderChatScreen] pour charger la conversation liée à [orderId].
class OrderChatArgs {
  final String orderId;
  const OrderChatArgs({required this.orderId});
}

/// Registre des constantes de chemins et générateur de routes de la Marketplace.
class MarketplaceRoutes {
  // Constructeur privé empêchant toute instanciation directe.
  MarketplaceRoutes._();

  static const String home = '/';
  static const String offerDetail = '/marketplace/offer-detail';
  static const String offerWizard = '/marketplace/offer-wizard';
  static const String orderCheckout = '/marketplace/order-checkout';
  static const String orderChat = '/marketplace/order-chat';

  /// Intercepte les appels `Navigator.pushNamed` / `pushReplacementNamed` et instancie
  /// la [MaterialPageRoute] correspondante en castant `settings.arguments` vers sa classe `*Args`.
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
