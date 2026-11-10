import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../features/forum/models/user.dart';
import '../providers/forum_provider.dart';
import 'forum_firestore_service.dart';

/// Relie le Forum au compte Firebase de l'application.
///
/// - Connexion : branche le [ForumProvider] sur Firestore avec l'identité réelle
///   (`uid`, nom et rôle lus dans `users/{uid}`, comme la Marketplace).
/// - Changement de rôle ou de nom dans `users/{uid}` : mis à jour en direct
///   (ex. après la validation d'un code enseignant).
/// - Déconnexion : le Forum revient au mode local (données d'exemple).
///
/// Sans Firebase configuré, [start] renvoie null et le Forum reste en mode local.
class ForumFirebaseLink {
  ForumFirebaseLink._(this._provider);

  final ForumProvider _provider;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  /// Démarre l'écoute du compte ; null si Firebase n'est pas initialisé.
  static ForumFirebaseLink? start(ForumProvider provider) {
    if (Firebase.apps.isEmpty) return null;
    final link = ForumFirebaseLink._(provider);
    link._authSub = FirebaseAuth.instance.authStateChanges().listen(
          link._onAuthChanged,
          onError: (Object error) =>
              debugPrint('Forum : état de connexion illisible ($error)'),
        );
    return link;
  }

  void _onAuthChanged(User? user) {
    _userSub?.cancel();
    _userSub = null;

    if (user == null) {
      _provider.disconnectRemote();
      return;
    }

    _provider.connectRemote(
      ForumFirestoreService(),
      user: _forumUser(user, null),
    );
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
          (doc) => _provider.updateRemoteUser(_forumUser(user, doc.data())),
          onError: (Object error) =>
              debugPrint('Forum : profil utilisateur illisible ($error)'),
        );
  }

  ForumUser _forumUser(User user, Map<String, dynamic>? profile) {
    final role =
        profile?['role'] == 'teacher' ? ForumRole.teacher : ForumRole.student;
    final profileName = (profile?['name'] as String?)?.trim();
    final name = (profileName != null && profileName.isNotEmpty)
        ? profileName
        : (user.displayName ?? user.email?.split('@').first ?? 'Utilisateur EduLink');
    return ForumUser(
      id: user.uid,
      name: name,
      role: role,
      title: role == ForumRole.teacher ? 'Enseignant' : null,
    );
  }

  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    _authSub = null;
    _userSub = null;
  }
}
