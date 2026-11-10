import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

// Préparation des notifications push réelles (Firebase Cloud Messaging) :
// demande de permission, récupération du jeton d'appareil et enregistrement
// dans le document `users/{uid}` (champ `fcmToken`). L'envoi des messages
// eux-mêmes sera confié à une Cloud Function (plan Blaze) ; en attendant,
// les notifications aux inscrits fonctionnent déjà dans l'application via
// la collection `notifications` (temps réel Firestore).
// Sans effet sur Windows/web : garde de plateforme + repli silencieux.

/// Initialisation FCM du module Cours, sûre sur toutes les plateformes.
class CoursesPushService {
  CoursesPushService._();

  static bool _initialized = false;

  /// Demande la permission, enregistre l'appareil auprès de FCM et
  /// enregistre chaque jeton émis pour l'utilisateur courant. Ne fait rien
  /// hors Android/iOS ou si Firebase n'est pas initialisé (tests, mode démo).
  static Future<void> init() async {
    if (_initialized || kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (Firebase.apps.isEmpty) return;
    _initialized = true;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      messaging.onRegistered.listen(_saveToken);
      await messaging.register();
    } catch (error) {
      debugPrint('[CoursesPush] FCM indisponible : $error');
    }
  }

  /// Relance l'enregistrement FCM pour l'utilisateur courant (après une
  /// connexion ou une inscription) afin que chaque compte ait le sien.
  static Future<void> refreshForCurrentUser() async {
    if (kIsWeb || Firebase.apps.isEmpty) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await FirebaseMessaging.instance.register();
    } catch (error) {
      debugPrint('[CoursesPush] Rafraîchissement du jeton impossible : $error');
    }
  }

  /// Écrit (ou met à jour) le jeton dans `users/{uid}` sans toucher aux
  /// autres champs du document — compatible avec les règles Firestore qui
  /// interdisent de modifier le champ `role`.
  static Future<void> _saveToken(String? token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (token == null || user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    } catch (error) {
      debugPrint('[CoursesPush] Enregistrement du jeton impossible : $error');
    }
  }
}
