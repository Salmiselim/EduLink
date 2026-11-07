import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Service gérant les notifications push réelles (Firebase Cloud Messaging)
/// pour le module Évaluations (Liaison L8)
class EvalNotificationService {
  static final EvalNotificationService instance = EvalNotificationService._();
  EvalNotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _initialized = false;

  /// Initialise FCM, enregistre le token de l'appareil dans Firestore
  /// et active l'écoute des notifications au premier plan.
  Future<void> init() async {
    if (_initialized) return;
    try {
      // 1. Demande de permission push (Android 13+ / iOS)
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('[FCM] Permission accordée');
      }

      // 2. Récupération et stockage du token FCM
      final token = await _fcm.getToken();
      if (token != null) {
        debugPrint('[FCM] Token appareil : $token');
        await _saveTokenToUser(token);
      }

      // Rafraîchissement du token
      _fcm.onTokenRefresh.listen(_saveTokenToUser);

      // 3. Écoute des messages quand l'application est au premier plan
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM Foreground] Reçu : ${message.notification?.title} - ${message.notification?.body}');
      });

      _initialized = true;
    } catch (e) {
      debugPrint('[FCM] Erreur init (non bloquant en local) : $e');
    }
  }

  /// Associe le token FCM au document utilisateur dans Firestore
  Future<void> _saveTokenToUser(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[FCM] Erreur sauvegarde token : $e');
      }
    }
  }

  /// Déclenche l'envoi d'une notification push aux étudiants (enregistrée dans la collection notifications)
  Future<void> notifyEvaluationCreated({
    required String courseId,
    required String title,
    required String type,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'courseId': courseId,
        'title': 'Nouvelle évaluation ($type)',
        'body': '« $title » a été publié par votre enseignant.',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'new_evaluation',
      });
    } catch (e) {
      debugPrint('[FCM] Notification création : $e');
    }
  }

  /// Déclenche une notification lorsqu'une note est publiée (L8)
  Future<void> notifyGradePublished({
    required String studentId,
    required String title,
    required double grade,
    required double maxGrade,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'studentId': studentId,
        'title': 'Note publiée',
        'body': 'Votre devoir « $title » a été corrigé : ${grade.toStringAsFixed(1)} / ${maxGrade.toStringAsFixed(0)}',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'grade_published',
      });
    } catch (e) {
      debugPrint('[FCM] Notification note : $e');
    }
  }
}
