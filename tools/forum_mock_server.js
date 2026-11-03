#!/usr/bin/env node
/**
 * Serveur REST de démonstration pour le module Forum (M3) — sans dépendance.
 *
 *   node tools/forum_mock_server.js          (port 3000 par défaut, PORT=4000 pour changer)
 *
 * Il implémente les endpoints du plan (en mémoire : les données disparaissent à l'arrêt)
 * pour montrer la communication HTTP réelle de l'application :
 *
 *   GET    /health
 *   GET    /posts/feed?limit=      POST /posts      PATCH|DELETE /posts/:id
 *   PATCH  /posts/:id/accept/:replyId               DELETE /posts/:id/accept
 *   GET    /replies                POST /replies    PATCH|DELETE /replies/:id
 *   PATCH  /replies/:id/verify     { "verified": true|false }
 *   GET    /reactions              PUT /reactions   DELETE /reactions?targetType=&targetId=&userId=
 *
 * Lancer l'application avec :
 *   flutter run --dart-define=FORUM_REMOTE=true
 * (l'émulateur Android joint ce PC via http://10.0.2.2:3000 ; sur un vrai téléphone,
 *  ajouter --dart-define=FORUM_API_URL=http://<ip-du-pc>:3000).
 */
'use strict';

const http = require('http');

const PORT = Number(process.env.PORT) || 3000;

/** @type {Map<string, any>} */ const posts = new Map();
/** @type {Map<string, any>} */ const replies = new Map();
/** @type {Map<string, any>} */ const reactions = new Map();

const reactionId = (r) => `${r.targetType}_${r.targetId}_${r.userId}`;

function send(res, status, payload) {
  if (payload === undefined) {
    res.writeHead(status);
    res.end();
    return;
  }
  const body = JSON.stringify(payload);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
  });
  res.end(body);
}

const fail = (res, status, message) => send(res, status, { message });

function readJson(req) {
  return new Promise((resolve, reject) => {
    let raw = '';
    req.on('data', (chunk) => {
      raw += chunk;
      if (raw.length > 1e6) reject(new Error('Corps trop volumineux'));
    });
    req.on('end', () => {
      if (!raw) return resolve({});
      try {
        resolve(JSON.parse(raw));
      } catch {
        reject(new Error('JSON invalide'));
      }
    });
    req.on('error', reject);
  });
}

function recount(postId) {
  const post = posts.get(postId);
  if (!post) return;
  post.repliesCount = [...replies.values()].filter((r) => r.postId === postId).length;
}

function removeReactionsOf(targetType, targetId) {
  for (const [key, r] of reactions) {
    if (r.targetType === targetType && r.targetId === targetId) reactions.delete(key);
  }
}

async function handle(req, res) {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const parts = url.pathname.split('/').filter(Boolean);
  const method = req.method;
  const [root, id, sub, subId] = parts;

  if (method === 'GET' && root === 'health') return send(res, 200, { ok: true });

  // ------------------------------------------------------------------ posts
  if (root === 'posts') {
    if (method === 'GET' && id === 'feed') {
      const limit = Number(url.searchParams.get('limit')) || 50;
      const items = [...posts.values()]
        .sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)))
        .slice(0, limit);
      return send(res, 200, { items });
    }

    if (method === 'POST' && !id) {
      const body = await readJson(req);
      if (typeof body.id !== 'string' || !body.id) return fail(res, 400, 'Identifiant manquant.');
      if (typeof body.title !== 'string' || !body.title.trim()) return fail(res, 400, 'Titre obligatoire.');
      if (typeof body.body !== 'string' || !body.body.trim()) return fail(res, 400, 'Description obligatoire.');
      posts.set(body.id, body);
      return send(res, 201, body);
    }

    const post = posts.get(id);

    if (method === 'PATCH' && id && !sub) {
      if (!post) return fail(res, 404, 'Question introuvable.');
      const body = await readJson(req);
      const updated = { ...post, ...body, id: post.id };
      posts.set(id, updated);
      return send(res, 200, updated);
    }

    if (method === 'DELETE' && id && !sub) {
      if (!post) return fail(res, 404, 'Question introuvable.');
      for (const [rid, reply] of replies) {
        if (reply.postId === id) {
          removeReactionsOf('reply', rid);
          replies.delete(rid);
        }
      }
      removeReactionsOf('post', id);
      posts.delete(id);
      return send(res, 204);
    }

    if (method === 'PATCH' && id && sub === 'accept' && subId) {
      if (!post) return fail(res, 404, 'Question introuvable.');
      const reply = replies.get(subId);
      if (!reply || reply.postId !== id) return fail(res, 404, 'Réponse introuvable.');
      post.acceptedReplyId = subId;
      post.status = 'resolved';
      return send(res, 200, post);
    }

    if (method === 'DELETE' && id && sub === 'accept') {
      if (!post) return fail(res, 404, 'Question introuvable.');
      post.acceptedReplyId = null;
      post.status = 'open';
      return send(res, 200, post);
    }
  }

  // ---------------------------------------------------------------- replies
  if (root === 'replies') {
    if (method === 'GET' && !id) return send(res, 200, { items: [...replies.values()] });

    if (method === 'POST' && !id) {
      const body = await readJson(req);
      if (typeof body.id !== 'string' || !body.id) return fail(res, 400, 'Identifiant manquant.');
      if (!posts.has(body.postId)) return fail(res, 404, 'Question introuvable.');
      if (typeof body.body !== 'string' || !body.body.trim()) return fail(res, 400, 'Réponse vide.');
      replies.set(body.id, body);
      recount(body.postId);
      return send(res, 201, body);
    }

    const reply = replies.get(id);

    if (method === 'PATCH' && id && sub === 'verify') {
      if (!reply) return fail(res, 404, 'Réponse introuvable.');
      const body = await readJson(req);
      reply.isTeacherVerified = body.verified === true;
      reply.verifiedAt = reply.isTeacherVerified ? new Date().toISOString() : null;
      return send(res, 200, reply);
    }

    if (method === 'PATCH' && id && !sub) {
      if (!reply) return fail(res, 404, 'Réponse introuvable.');
      const body = await readJson(req);
      const updated = { ...reply, ...body, id: reply.id, postId: reply.postId };
      replies.set(id, updated);
      return send(res, 200, updated);
    }

    if (method === 'DELETE' && id && !sub) {
      if (!reply) return fail(res, 404, 'Réponse introuvable.');
      replies.delete(id);
      removeReactionsOf('reply', id);
      const post = posts.get(reply.postId);
      if (post && post.acceptedReplyId === id) {
        post.acceptedReplyId = null;
        post.status = 'open';
      }
      recount(reply.postId);
      return send(res, 204);
    }
  }

  // -------------------------------------------------------------- reactions
  if (root === 'reactions') {
    if (method === 'GET') return send(res, 200, { items: [...reactions.values()] });

    if (method === 'PUT') {
      const body = await readJson(req);
      if (!body.targetType || !body.targetId || !body.userId || !body.type) {
        return fail(res, 400, 'Réaction incomplète.');
      }
      reactions.set(reactionId(body), body);
      return send(res, 200, body);
    }

    if (method === 'DELETE') {
      const key = reactionId({
        targetType: url.searchParams.get('targetType'),
        targetId: url.searchParams.get('targetId'),
        userId: url.searchParams.get('userId'),
      });
      if (!reactions.delete(key)) return fail(res, 404, 'Réaction introuvable.');
      return send(res, 204);
    }
  }

  return fail(res, 404, `Route inconnue : ${method} ${url.pathname}`);
}

const server = http.createServer(async (req, res) => {
  const started = Date.now();
  res.on('finish', () => {
    console.log(`${req.method} ${req.url} -> ${res.statusCode} (${Date.now() - started} ms)`);
  });
  try {
    await handle(req, res);
  } catch (error) {
    fail(res, 400, error.message || 'Requête invalide.');
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Forum mock server prêt sur http://localhost:${PORT}  (Ctrl+C pour arrêter)`);
});
