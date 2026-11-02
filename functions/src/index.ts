/**
 * Cloud Functions du backend EduLink.
 *
 * Dans l'architecture Firebase-direct, ces fonctions remplacent les traitements
 * planifiés et sensibles qui auraient vécu dans un serveur NestJS :
 * - l'attribution de badges (vérification de rattrapage nocturne) ;
 * - la modération automatique des offres signalées ;
 * - la validation des codes d'établissement à l'inscription enseignant.
 */
import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';

initializeApp();

const db = getFirestore();

/** Nombre de signalements avant masquage automatique d'une offre. */
const REPORTS_THRESHOLD = 3;

// ─────────────────────────────────────────────────────────────────────────────
// Modération : une nouvelle fonctionnalité de signalement masque automatiquement
// l'offre dès que son compteur atteint le seuil.
// ─────────────────────────────────────────────────────────────────────────────
export const onReportCreated = onDocumentCreated(
  'reports/{reportId}',
  async (event) => {
    const data = event.data?.data();
    const offerId = data?.['offerId'] as string | undefined;
    if (!offerId) return;

    const offerRef = db.collection('offers').doc(offerId);
    await db.runTransaction(async (tx) => {
      const snapshot = await tx.get(offerRef);
      if (!snapshot.exists) return;
      const reportsCount = ((snapshot.data()?.['reportsCount'] as number) ?? 0) + 1;
      const update: Record<string, unknown> = { reportsCount };
      if (reportsCount >= REPORTS_THRESHOLD) {
        update['status'] = 'hidden';
      }
      tx.update(offerRef, update);
    });
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// Badges : vérification de rattrapage nocturne (les événements courants
// attribuent déjà en direct ; cette fonction rattrape les cas manqués).
// ─────────────────────────────────────────────────────────────────────────────
export const nightlyBadgeCheck = onSchedule('every day 03:00', async () => {
  const badges = await db.collection('badges').get();
  if (badges.empty) return;

  const users = await db.collection('users').select('role').get();
  let granted = 0;

  for (const user of users.docs) {
    for (const badge of badges.docs) {
      const entryRef = db.collection('user_badges').doc(`${user.id}_${badge.id}`);
      const entry = await entryRef.get();
      if (entry.exists) continue;

      // TODO(semaine 4) : calculer la métrique réelle de chaque badge
      // (cours terminés, réponses utiles, quiz réussis, ventes...) d'après
      // badge.data().metric / threshold, puis attribuer si le seuil est atteint.
      const metricValue = 0;
      const threshold = (badge.data()['threshold'] as number) ?? Number.MAX_SAFE_INTEGER;

      if (metricValue >= threshold) {
        await entryRef.set({
          userId: user.id,
          badgeId: badge.id,
          awardedAt: FieldValue.serverTimestamp(),
        });
        granted++;
      }
    }
  }

  console.log(`nightlyBadgeCheck : ${granted} badge(s) attribué(s).`);
});

// ─────────────────────────────────────────────────────────────────────────────
// Inscription enseignant : valide le code d'établissement (collection
// invite_codes, illisible côté client) puis bascule le rôle du compte.
// ─────────────────────────────────────────────────────────────────────────────
export const redeemInviteCode = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Connexion requise.');
  }
  const inviteCode = (request.data as { inviteCode?: string })?.inviteCode;
  if (!inviteCode) {
    throw new HttpsError('invalid-argument', 'Code manquant.');
  }

  const codeRef = db.collection('invite_codes').doc(inviteCode);
  const codeDoc = await codeRef.get();
  if (!codeDoc.exists) {
    throw new HttpsError('permission-denied', 'Code invalide.');
  }
  const expiresAt = codeDoc.data()?.['expiresAt']?.toDate?.() as Date | undefined;
  if (expiresAt && expiresAt < new Date()) {
    throw new HttpsError('permission-denied', 'Code expiré.');
  }

  await db.collection('users').doc(request.auth.uid).update({ role: 'teacher' });
  await codeRef.update({ usedCount: FieldValue.increment(1) });

  return { ok: true, role: 'teacher' };
});
