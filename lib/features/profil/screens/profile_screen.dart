import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/services/auth_service.dart';
import '../../auth/screens/sign_in_screen.dart';
import '../../auth/widgets/auth_ui.dart';

// ============================================================================
// ÉCRAN PROFIL — onglet Profil (module Comptes)
// Minimaliste : identité du compte connecté (nom, e-mail, rôle, ancienneté)
// et déconnexion. En mode démonstration (aucun compte Firebase), affiche un
// bandeau dédié avec un raccourci vers la connexion.
// ============================================================================

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ready = AuthService.instance.isFirebaseReady;
    final user = AuthService.instance.currentUser;

    return Scaffold(
      backgroundColor: AuthColors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AuthColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EduLink · Profil',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AuthColors.text,
                    ),
                  ),
                  Text(
                    'Compte & préférences',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AuthColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: (!ready || user == null)
          ? _buildDemoBody(context)
          : _buildSignedInBody(context, user),
    );
  }

  // ── Mode démonstration : pas de compte Firebase connecté ──────────────────

  Widget _buildDemoBody(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AuthColors.infoBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                size: 34,
                color: AuthColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Mode démonstration',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AuthColors.text,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Aucun compte connecté — connecte-toi pour retrouver ton "
              'profil, ton rôle et tes badges.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AuthColors.muted,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 220,
              height: 46,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                    (route) => false,
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AuthColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text(
                  'Se connecter',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Compte connecté : identité + informations + déconnexion ───────────────

  Widget _buildSignedInBody(BuildContext context, User user) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final name =
            (data['name'] as String?) ?? user.displayName ?? 'Utilisateur EduLink';
        final email = (data['email'] as String?) ?? user.email ?? '';
        final role = (data['role'] as String?) ?? 'student';
        final isTeacher = role == 'teacher';
        final createdAt = data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate()
            : null;
        final initials = name
            .split(' ')
            .where((p) => p.isNotEmpty)
            .map((p) => p[0])
            .take(2)
            .join()
            .toUpperCase();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Carte d'identité ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AuthColors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AuthColors.infoBg,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AuthColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AuthColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AuthColors.muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isTeacher
                                ? AuthColors.infoBg
                                : AuthColors.neutralBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isTeacher
                                    ? Icons.verified_rounded
                                    : Icons.school_outlined,
                                size: 12,
                                color: isTeacher
                                    ? const Color(0xFF1D4ED8)
                                    : AuthColors.muted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isTeacher ? 'Enseignant vérifié' : 'Étudiant',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isTeacher
                                      ? const Color(0xFF1D4ED8)
                                      : AuthColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Informations du compte ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AuthColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informations du compte',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AuthColors.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _accountRow(
                    Icons.mail_outline_rounded,
                    'E-mail',
                    email,
                  ),
                  _accountRow(
                    isTeacher
                        ? Icons.verified_outlined
                        : Icons.school_outlined,
                    'Rôle',
                    isTeacher ? 'Enseignant' : 'Étudiant',
                  ),
                  if (createdAt != null)
                    _accountRow(
                      Icons.event_outlined,
                      'Membre depuis',
                      '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // ── Déconnexion ──
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await AuthService.instance.signOut();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                    (route) => false,
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AuthColors.danger,
                  side: const BorderSide(color: AuthColors.danger),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text(
                  'Se déconnecter',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'EduLink — apprendre, échanger, progresser',
                style: TextStyle(fontSize: 11, color: AuthColors.muted),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _accountRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AuthColors.muted),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AuthColors.muted,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AuthColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
