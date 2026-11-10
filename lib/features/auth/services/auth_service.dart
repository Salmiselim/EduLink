import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

// ============================================================================
// SERVICE D'AUTHENTIFICATION — module Comptes
// Deux modes, choisis automatiquement :
// - Firebase configuré (firebase_options / google-services.json présents) :
//   vraie connexion via Firebase Authentication + création du document
//   `users/{uid}` (nom, e-mail, rôle).
// - Firebase absent : mode démonstration — toute saisie valide ouvre
//   l'application, aucun compte n'est créé.
// ============================================================================

/// Issue d'une tentative d'authentification.
enum AuthOutcome {
  /// Compte réellement créé / connecté côté Firebase.
  success,

  /// Firebase non configuré : ouverture de l'application en démonstration.
  demo,

  /// Échec réel (identifiants invalides, e-mail déjà utilisé...).
  failure,
}

/// Résultat : [AuthOutcome] + message d'erreur éventuel (en cas d'échec).
typedef AuthResult = ({AuthOutcome outcome, String? error});

class AuthService {
  static final AuthService instance = AuthService._();

  AuthService._();

  /// Hook déclenché après une connexion ou inscription réussie — branché dans
  /// `main.dart` pour connecter les modules à Firestore avec le vrai uid.
  static Future<void> Function(User user)? onSignedIn;

  /// Vrai uniquement si Firebase a pu s'initialiser au démarrage.
  bool get isFirebaseReady => Firebase.apps.isNotEmpty;

  FirebaseAuth? get _auth => isFirebaseReady ? FirebaseAuth.instance : null;

  FirebaseFirestore? get _db =>
      isFirebaseReady ? FirebaseFirestore.instance : null;

  /// Utilisateur Firebase connecté (null en mode démonstration).
  User? get currentUser => _auth?.currentUser;

  /// Connexion e-mail / mot de passe.
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    if (!isFirebaseReady) {
      return (outcome: AuthOutcome.demo, error: null);
    }
    try {
      await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = _auth!.currentUser;
      if (user != null && onSignedIn != null) {
        await onSignedIn!(user);
      }
      return (outcome: AuthOutcome.success, error: null);
    } on FirebaseAuthException catch (e) {
      return (outcome: AuthOutcome.failure, error: _message(e.code));
    } catch (_) {
      return (
        outcome: AuthOutcome.failure,
        error: 'Connexion impossible pour le moment.',
      );
    }
  }

  /// Inscription : crée le compte Firebase puis le document `users/{uid}`
  /// avec le rôle choisi (étudiant / enseignant avec code d'établissement).
  Future<AuthResult> signUp({
    required String name,
    required String email,
    required String password,
    required bool isTeacher,
    String? teacherCode,
  }) async {
    if (!isFirebaseReady) {
      return (outcome: AuthOutcome.demo, error: null);
    }
    try {
      final credential = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;
      await _db!.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'role': isTeacher ? 'teacher' : 'student',
        'university': null,
        'badges': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
      final user = credential.user!;
      if (onSignedIn != null) {
        await onSignedIn!(user);
      }
      return (outcome: AuthOutcome.success, error: null);
    } on FirebaseAuthException catch (e) {
      return (outcome: AuthOutcome.failure, error: _message(e.code));
    } catch (_) {
      return (
        outcome: AuthOutcome.failure,
        error: 'Inscription impossible pour le moment.',
      );
    }
  }

  /// Déconnexion (sans effet en mode démonstration).
  Future<void> signOut() async {
    if (isFirebaseReady) {
      await _auth!.signOut();
    }
  }

  /// Envoie l'e-mail officiel de réinitialisation de mot de passe (Firebase).
  /// En mode démonstration (Firebase absent), le flux reste utilisable et
  /// l'issue `demo` est retournée : l'interface génère alors son propre code.
  Future<AuthResult> sendPasswordReset({required String email}) async {
    if (!isFirebaseReady) {
      return (outcome: AuthOutcome.demo, error: null);
    }
    try {
      await _auth!.sendPasswordResetEmail(email: email);
      return (outcome: AuthOutcome.success, error: null);
    } on FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        'user-not-found' => "Aucun compte EduLink n'est associé à cet e-mail.",
        _ => _message(e.code),
      };
      return (outcome: AuthOutcome.failure, error: message);
    } catch (_) {
      return (
        outcome: AuthOutcome.failure,
        error: 'Envoi impossible pour le moment.',
      );
    }
  }

  /// Messages d'erreur lisibles pour les codes Firebase courants.
  String _message(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Adresse e-mail invalide.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou mot de passe incorrect.';
      case 'user-disabled':
        return 'Ce compte a été désactivé.';
      case 'email-already-in-use':
        return 'Un compte existe déjà avec cet e-mail.';
      case 'weak-password':
        return 'Mot de passe trop faible (6 caractères minimum).';
      case 'too-many-requests':
        return 'Trop de tentatives — réessayez dans un instant.';
      default:
        return 'Erreur : $code';
    }
  }
}
