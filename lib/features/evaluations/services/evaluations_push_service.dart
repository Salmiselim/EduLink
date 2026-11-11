import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../courses/data/courses_mock_data.dart';
import '../../courses/models/courses_models.dart';

/// Modèle traçant un envoi de notification push aux étudiants inscrits d'un cours.
class EvaluationPushEvent {
  final String courseId;
  final String courseTitle;
  final String type;
  final String title;
  final String body;
  final List<String> recipientStudentIds;
  final DateTime sentAt;

  const EvaluationPushEvent({
    required this.courseId,
    required this.courseTitle,
    required this.type,
    required this.title,
    required this.body,
    required this.recipientStudentIds,
    required this.sentAt,
  });
}

/// Service de notifications push (L8 — FCM + Temps réel Firestore) du module
/// Évaluations.
///
/// Fonctionnement :
/// 1. Lorsqu'un enseignant publie un **quiz**, un **devoir (dépôt)** ou un
///    **document**, [notifyCourseStudents] cible uniquement les étudiants
///    inscrits à ce cours (`enrollments` où `courseId == item.courseId`).
/// 2. Pour chaque étudiant inscrit :
///    - Crée une notification temps réel dans la collection Firestore
///      `notifications` (conforme à la règle de sécurité
///      `exists(.../enrollments/$(courseId + '_' + userId))`) ainsi qu'en
///      mémoire via [CoursesController.notifyEnrolledStudents].
///    - Si les jetons FCM (`fcmToken` dans `users/{studentId}`) et une passerelle
///      HTTP push (`FCM_PUSH_RELAY_URL` dans `.env`) sont configurés, déclenche
///      également la notification système FCM distante.
/// 3. Côté étudiant connecté, [subscribeToRealtimePushes] écoute en temps réel
///    les nouvelles notifications non lues et déclenche immédiatement une
///    bannière push au premier plan ([onForegroundNotification]) ainsi que la
///    mise à jour du badge sur la cloche des notifications.
class EvaluationsPushService {
  EvaluationsPushService._();

  static final EvaluationsPushService instance = EvaluationsPushService._();

  bool _fcmInitialized = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _realtimeSub;
  final Set<String> _knownNotificationIds = <String>{};
  bool _initialSnapshotLoaded = false;

  /// Callback déclenché lorsqu'une nouvelle notification push arrive en temps
  /// réel pour l'étudiant connecté (affiche une bannière push dans le shell).
  void Function(CourseNotification notification)? onForegroundNotification;

  /// Historique des notifications push émises durant la session (utile pour
  /// le diagnostic et les tests unitaires).
  final List<EvaluationPushEvent> sentHistory = [];

  /// Réinitialise l'historique des notifications envoyées (tests unitaires).
  void clearHistory() => sentHistory.clear();

  /// Initialise Firebase Cloud Messaging (permission + enregistrement du
  /// `fcmToken` dans `users/{uid}`) sur Android/iOS, et démarre l'écoute
  /// temps réel des notifications push pour l'utilisateur courant.
  Future<void> init() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      if (!_fcmInitialized && Firebase.apps.isNotEmpty) {
        _fcmInitialized = true;
        try {
          final messaging = FirebaseMessaging.instance;
          await messaging.requestPermission();
          messaging.onRegistered.listen(_saveFcmToken);
          await messaging.register();
        } catch (e) {
          debugPrint('[EvalPush] FCM indisponible sur cette plateforme : $e');
        }
      }
    }
    subscribeToRealtimePushes();
  }

  /// Met à jour l'abonnement temps réel aux notifications push pour le compte
  /// Firebase actuellement connecté.
  void subscribeToRealtimePushes() {
    if (Firebase.apps.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      stopRealtimePushes();
      return;
    }
    _realtimeSub?.cancel();
    _knownNotificationIds.clear();
    _initialSnapshotLoaded = false;

    _realtimeSub = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen(
      (snapshot) {
        if (!_initialSnapshotLoaded) {
          for (final doc in snapshot.docs) {
            _knownNotificationIds.add(doc.id);
          }
          _initialSnapshotLoaded = true;
          return;
        }
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final doc = change.doc;
            if (_knownNotificationIds.add(doc.id)) {
              final d = doc.data();
              if (d == null) continue;
              final isRead = (d['read'] as bool?) ?? false;
              if (!isRead && onForegroundNotification != null) {
                final notif = CourseNotification(
                  id: doc.id,
                  userId: (d['userId'] as String?) ?? '',
                  fromId: (d['fromId'] as String?) ?? '',
                  courseId: (d['courseId'] as String?) ?? '',
                  courseTitle: (d['courseTitle'] as String?) ?? '',
                  type: (d['type'] as String?) ?? 'evaluation',
                  title: (d['title'] as String?) ?? 'Nouvelle notification',
                  body: (d['body'] as String?) ?? '',
                  createdAt:
                      (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                  read: false,
                );
                onForegroundNotification!(notif);
              }
            }
          }
        }
      },
      onError: (e) => debugPrint('[EvalPush] Erreur flux notifications : $e'),
    );
  }

  /// Coupe l'écoute temps réel lors de la déconnexion.
  void stopRealtimePushes() {
    _realtimeSub?.cancel();
    _realtimeSub = null;
    _knownNotificationIds.clear();
    _initialSnapshotLoaded = false;
  }

  Future<void> _saveFcmToken(String? token) async {
    if (token == null || Firebase.apps.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[EvalPush] Impossible d\'enregistrer fcmToken : $e');
    }
  }

  /// Envoie une notification push à **tous les étudiants inscrits** au cours
  /// [courseId] lorsqu'un enseignant publie un quiz, un devoir ou un document.
  Future<EvaluationPushEvent> notifyCourseStudents({
    required String courseId,
    required String courseTitle,
    required String type,
    required String title,
    required String body,
    required String senderId,
  }) async {
    final coursesCtrl = CoursesController.instance;
    final resolvedCourseTitle = courseTitle.trim().isNotEmpty
        ? courseTitle.trim()
        : (coursesCtrl.courseById(courseId)?.title ?? courseId);

    // 1. Notifie via CoursesController (alimente la liste en mémoire pour le
    //    mode démo / tests ET écrit dans la collection `notifications` de
    //    Firestore lorsque CoursesCloudController est connecté).
    final notifiedIds = <String>{
      ...coursesCtrl.notifyEnrolledStudents(
        courseId,
        type: type,
        title: title,
        body: body,
        courseTitleFallback: resolvedCourseTitle,
        senderIdOverride: senderId,
      ),
    };

    // 2. Si Firebase est actif, interroge aussi directement `enrollments` pour
    //    couvrir le cas où CoursesController n'aurait pas encore chargé les
    //    inscriptions en mémoire, et déclenche l'envoi push FCM aux appareils.
    if (Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null) {
      try {
        final db = FirebaseFirestore.instance;
        final uid = FirebaseAuth.instance.currentUser!.uid;
        final snap = await db
            .collection('enrollments')
            .where('courseId', isEqualTo: courseId)
            .get();

        final cloudOnlyStudents = <String>[];
        for (final doc in snap.docs) {
          final studentId = doc.data()['studentId'] as String?;
          if (studentId == null || studentId.isEmpty || studentId == uid) {
            continue;
          }
          if (notifiedIds.add(studentId)) {
            cloudOnlyStudents.add(studentId);
          }
        }

        // Si CoursesController était encore en mode démo ou n'avait pas écrit
        // pour certains inscrits, on persiste leurs notifications Firestore.
        if (coursesCtrl.isDemoMode && notifiedIds.isNotEmpty) {
          final batch = db.batch();
          for (final studentId in notifiedIds) {
            batch.set(db.collection('notifications').doc(), {
              'userId': studentId,
              'fromId': uid,
              'courseId': courseId,
              'courseTitle': resolvedCourseTitle,
              'type': type,
              'title': title,
              'body': body,
              'read': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
          await batch.commit();
        } else if (cloudOnlyStudents.isNotEmpty) {
          final batch = db.batch();
          for (final studentId in cloudOnlyStudents) {
            batch.set(db.collection('notifications').doc(), {
              'userId': studentId,
              'fromId': uid,
              'courseId': courseId,
              'courseTitle': resolvedCourseTitle,
              'type': type,
              'title': title,
              'body': body,
              'read': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
          await batch.commit();
        }

        // 3. Relais HTTP push optionnel (FCM / Webhook) pour les appareils
        //    ayant enregistré un `fcmToken` dans `users/{studentId}`.
        await _dispatchFcmRelayIfConfigured(
          studentIds: notifiedIds.toList(),
          title: title,
          body: body,
          data: {
            'courseId': courseId,
            'courseTitle': resolvedCourseTitle,
            'type': type,
          },
        );
      } catch (e) {
        debugPrint('[EvalPush] Erreur lors de l\'envoi push Firestore : $e');
      }
    }

    final event = EvaluationPushEvent(
      courseId: courseId,
      courseTitle: resolvedCourseTitle,
      type: type,
      title: title,
      body: body,
      recipientStudentIds: notifiedIds.toList(growable: false),
      sentAt: DateTime.now(),
    );
    sentHistory.insert(0, event);
    debugPrint(
      '[EvalPush] Notification "$type" envoyée à ${notifiedIds.length} '
      'étudiant(s) inscrit(s) au cours $courseId ($resolvedCourseTitle).',
    );
    return event;
  }

  /// Envoie une notification ciblée à un étudiant précis (ex. copie corrigée).
  Future<void> notifySingleStudent({
    required String studentId,
    required String courseId,
    required String courseTitle,
    required String type,
    required String title,
    required String body,
    required String senderId,
  }) async {
    if (studentId.isEmpty || studentId == senderId) return;
    final coursesCtrl = CoursesController.instance;
    final resolvedCourseTitle = courseTitle.trim().isNotEmpty
        ? courseTitle.trim()
        : (coursesCtrl.courseById(courseId)?.title ?? courseId);

    if (Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null) {
      try {
        final db = FirebaseFirestore.instance;
        final uid = FirebaseAuth.instance.currentUser!.uid;
        await db.collection('notifications').add({
          'userId': studentId,
          'fromId': uid,
          'courseId': courseId,
          'courseTitle': resolvedCourseTitle,
          'type': type,
          'title': title,
          'body': body,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await _dispatchFcmRelayIfConfigured(
          studentIds: [studentId],
          title: title,
          body: body,
          data: {
            'courseId': courseId,
            'courseTitle': resolvedCourseTitle,
            'type': type,
          },
        );
      } catch (e) {
        debugPrint('[EvalPush] notifySingleStudent : $e');
      }
    }
  }

  /// Si une URL de relais push (`FCM_PUSH_RELAY_URL`) est définie dans `.env`,
  /// récupère les `fcmToken` des étudiants destinataires et poste la charge
  /// utile JSON afin de déclencher une notification système native même
  /// lorsque l'application est fermée.
  Future<void> _dispatchFcmRelayIfConfigured({
    required List<String> studentIds,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    if (studentIds.isEmpty || Firebase.apps.isEmpty) return;
    String? relayUrl;
    try {
      if (dotenv.isInitialized) {
        relayUrl = dotenv.maybeGet('FCM_PUSH_RELAY_URL')?.trim();
      }
    } catch (_) {}
    if (relayUrl == null || relayUrl.isEmpty) return;

    try {
      final db = FirebaseFirestore.instance;
      final tokens = <String>[];
      for (final studentId in studentIds) {
        final userDoc = await db.collection('users').doc(studentId).get();
        final token = userDoc.data()?['fcmToken'] as String?;
        if (token != null && token.trim().isNotEmpty) {
          tokens.add(token.trim());
        }
      }
      if (tokens.isEmpty) return;

      await http
          .post(
            Uri.parse(relayUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'tokens': tokens,
              'notification': {'title': title, 'body': body},
              'data': data,
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[EvalPush] Relais FCM HTTP ignoré : $e');
    }
  }
}
