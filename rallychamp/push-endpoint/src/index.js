/**
 * RallyChamp push sender.
 *
 * A phone cannot send to an FCM topic — only something holding the
 * project's service-account key can, and that key can never ship inside
 * the APK or anyone who unzips it could broadcast fake crash alerts. This
 * endpoint is that "something": a free serverless function that holds the
 * key as an encrypted secret.
 *
 * The client only ever says "push event E of rally R". It does NOT get to
 * supply the title or body — this reads the event document back out of
 * Firestore and composes the message from the stored fields, so a
 * tampered-with client can't put arbitrary text on every spectator's
 * lock screen.
 *
 * See dev_notes.md §5 "Retracting a log entry, and notification
 * groundwork" for why this exists rather than a Cloud Function.
 */

/** Which events are worth interrupting someone for, and how loudly. */
const PUSHABLE_STATUSES = {
  start: { channel: 'rally_status', title: 'Rally starting' },
  running: { channel: 'rally_status', title: 'Rally active' },
  paused: { channel: 'rally_status', title: 'Rally paused' },
};

/**
 * Which per-stage changes are worth a push. A stage going live matters to
 * a marshal standing at it and to spectators deciding where to be, and a
 * cancelled stage is exactly the thing people need to hear before driving
 * to it. A stage merely *finishing* is routine — the results arriving are
 * the interesting part of that — and `scheduled` is a correction, so
 * neither buzzes anyone.
 */
const PUSHABLE_STAGE_STATUSES = {
  running: { channel: 'rally_status' },
  cancelled: { channel: 'rally_status' },
};

const INCIDENT_TYPES = {
  incident_opened: { channel: 'rally_incidents' },
  incident_resolved: { channel: 'rally_status' },
};

/** An event older than this is a replay, not news. */
const MAX_EVENT_AGE_MS = 10 * 60 * 1000;

const FIRESTORE = 'https://firestore.googleapis.com/v1';
const SCOPES = [
  'https://www.googleapis.com/auth/datastore',
  'https://www.googleapis.com/auth/firebase.messaging',
].join(' ');

export default {
  async fetch(request, env) {
    if (request.method !== 'POST') {
      return json({ error: 'method_not_allowed' }, 405);
    }

    try {
      const { rallyId, eventId } = await request.json();
      if (!rallyId || !eventId) {
        return json({ error: 'missing_rally_or_event' }, 400);
      }

      // 1. Who is calling? An unverified uid from the request body would
      //    make the admin check below meaningless, so this verifies the
      //    Firebase ID token's signature against Google's public keys.
      const idToken = (request.headers.get('authorization') || '').replace(
        /^Bearer /,
        '',
      );
      const caller = await verifyFirebaseIdToken(idToken, env.FIREBASE_PROJECT_ID);
      if (!caller) return json({ error: 'unauthenticated' }, 401);

      const accessToken = await getAccessToken(env);

      // 2. Are they allowed to speak for this rally? Checked against the
      //    real rally document, never against a claim from the client.
      //    Accepted staff count too, not just organizers — the whole point
      //    of incident reporting is that the marshal who sees the crash
      //    raises the alarm, and that marshal is not an admin.
      const rally = await getDoc(
        env,
        accessToken,
        `rallies/${rallyId}`,
      );
      if (!rally) return json({ error: 'rally_not_found' }, 404);
      if (!(await canSpeakForRally(env, accessToken, rally, rallyId, caller.uid))) {
        return json({ error: 'forbidden' }, 403);
      }

      // 3. Read the event and decide — from what's stored, not what was
      //    claimed — whether it's something worth pushing at all.
      const event = await getDoc(
        env,
        accessToken,
        `rallies/${rallyId}/events/${eventId}`,
      );
      if (!event) return json({ error: 'event_not_found' }, 404);

      const decision = decideMessage(event);
      if (!decision) return json({ skipped: 'not_pushable' }, 200);

      const occurredAt = Date.parse(
        event.fields?.occurredAt?.timestampValue || '',
      );
      if (!occurredAt || Date.now() - occurredAt > MAX_EVENT_AGE_MS) {
        return json({ skipped: 'too_old' }, 200);
      }

      // 4. Has this event already been pushed? The marker lives in its own
      //    collection rather than on the event, so the log itself stays
      //    genuinely immutable.
      const marker = `rallies/${rallyId}/pushes/${eventId}`;
      if (await getDoc(env, accessToken, marker)) {
        return json({ skipped: 'already_sent' }, 200);
      }

      // Sent before the marker is written on purpose: a duplicate alert is
      // an annoyance, a missing crash alert is a safety problem. A retry
      // after a failed send is therefore still able to get through.
      await sendToTopic(env, accessToken, `rally_${rallyId}`, decision);
      await createDoc(env, accessToken, marker, {
        sentAt: { timestampValue: new Date().toISOString() },
      });

      return json({ sent: true, channel: decision.channel }, 200);
    } catch (error) {
      return json({ error: 'internal', detail: `${error}` }, 500);
    }
  },
};

/** An organizer, or an accepted marshal/judge on this rally. */
async function canSpeakForRally(env, accessToken, rally, rallyId, uid) {
  const admins = (rally.fields?.adminUids?.arrayValue?.values || []).map(
    (v) => v.stringValue,
  );
  if (admins.includes(uid)) return true;

  const application = await getDoc(
    env,
    accessToken,
    `rallies/${rallyId}/staffApplications/${uid}`,
  );
  return application?.fields?.status?.stringValue === 'accepted';
}

/** Composes the notification from the stored event, or null to skip it. */
function decideMessage(event) {
  const fields = event.fields || {};
  if (fields.retractedAt) return null; // withdrawn — nothing to announce

  const type = fields.type?.stringValue;
  const title = fields.title?.stringValue || 'Rally update';

  if (type === 'status_change') {
    const rule = PUSHABLE_STATUSES[fields.status?.stringValue];
    // Deliberately not every status: setup and lunch break never push.
    // If routine changes buzzed like incidents, people would turn
    // notifications off and miss the one that matters.
    return rule ? { channel: rule.channel, title: rule.title, body: '' } : null;
  }

  if (type === 'stage_status_change') {
    const rule = PUSHABLE_STAGE_STATUSES[fields.status?.stringValue];
    // The stored title already names the stage ("SS2 running"), which is
    // the whole message — composing one here would risk saying something
    // different from the log row it came from.
    return rule ? { channel: rule.channel, title, body: '' } : null;
  }

  const incident = INCIDENT_TYPES[type];
  if (!incident) return null;
  return {
    channel: incident.channel,
    title,
    body: fields.detail?.stringValue || '',
  };
}

async function sendToTopic(env, accessToken, topic, decision) {
  const loud = decision.channel === 'rally_incidents';
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/messages:send`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${accessToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          topic,
          notification: { title: decision.title, body: decision.body },
          data: { channel: decision.channel },
          android: {
            priority: loud ? 'HIGH' : 'NORMAL',
            notification: { channel_id: decision.channel },
          },
        },
      }),
    },
  );
  if (!response.ok) {
    throw new Error(`fcm ${response.status}: ${await response.text()}`);
  }
}

// --- Firestore REST -------------------------------------------------------

async function getDoc(env, accessToken, path) {
  const response = await fetch(
    `${FIRESTORE}/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/${path}`,
    { headers: { authorization: `Bearer ${accessToken}` } },
  );
  if (response.status === 404) return null;
  if (!response.ok) {
    throw new Error(`firestore ${response.status}: ${await response.text()}`);
  }
  return response.json();
}

async function createDoc(env, accessToken, path, fields) {
  // `currentDocument.exists=false` makes this create-if-absent, so two
  // concurrent retries can't both claim the same marker.
  const response = await fetch(
    `${FIRESTORE}/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/${path}?currentDocument.exists=false`,
    {
      method: 'PATCH',
      headers: {
        authorization: `Bearer ${accessToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({ fields }),
    },
  );
  // A lost race here means someone else already recorded the send, which
  // is not an error worth failing the request over.
  if (!response.ok && response.status !== 409) {
    throw new Error(`firestore ${response.status}: ${await response.text()}`);
  }
}

// --- Auth -----------------------------------------------------------------

let cachedToken = null;

/**
 * Mints a Google access token from the service account. Cached in the
 * isolate until shortly before it expires — minting costs an extra
 * round trip, and this endpoint is on the path of a crash alert.
 */
async function getAccessToken(env) {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) {
    return cachedToken.value;
  }

  const account = JSON.parse(env.SERVICE_ACCOUNT_JSON);
  const now = Math.floor(Date.now() / 1000);
  const assertion = await signJwt(
    {
      iss: account.client_email,
      scope: SCOPES,
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    },
    account.private_key,
  );

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!response.ok) {
    throw new Error(`token ${response.status}: ${await response.text()}`);
  }
  const body = await response.json();
  cachedToken = {
    value: body.access_token,
    expiresAt: Date.now() + body.expires_in * 1000,
  };
  return cachedToken.value;
}

async function signJwt(claims, privateKeyPem) {
  const header = { alg: 'RS256', typ: 'JWT' };
  const unsigned = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(claims))}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToBuffer(privateKeyPem),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  return `${unsigned}.${b64urlBytes(new Uint8Array(signature))}`;
}

let cachedJwks = null;

/**
 * Verifies a Firebase ID token: signature against Google's published keys,
 * then the claims. Without the signature check, anyone could post a
 * hand-written token claiming to be a rally admin.
 */
async function verifyFirebaseIdToken(token, projectId) {
  const parts = (token || '').split('.');
  if (parts.length !== 3) return null;

  const header = JSON.parse(fromB64url(parts[0]));
  const claims = JSON.parse(fromB64url(parts[1]));

  if (claims.aud !== projectId) return null;
  if (claims.iss !== `https://securetoken.google.com/${projectId}`) return null;
  if (!claims.sub) return null;
  if (claims.exp * 1000 < Date.now()) return null;

  if (!cachedJwks || cachedJwks.expiresAt < Date.now()) {
    const response = await fetch(
      'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com',
    );
    cachedJwks = {
      keys: (await response.json()).keys,
      expiresAt: Date.now() + 60 * 60 * 1000,
    };
  }
  const jwk = cachedJwks.keys.find((k) => k.kid === header.kid);
  if (!jwk) return null;

  const key = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
  const valid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    bytesFromB64url(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  return valid ? { uid: claims.sub } : null;
}

// --- Encoding helpers -----------------------------------------------------

function json(body, status) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

function b64url(text) {
  return b64urlBytes(new TextEncoder().encode(text));
}

function b64urlBytes(bytes) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function bytesFromB64url(value) {
  const binary = atob(value.replace(/-/g, '+').replace(/_/g, '/'));
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function fromB64url(value) {
  return new TextDecoder().decode(bytesFromB64url(value));
}

function pemToBuffer(pem) {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  return bytesFromB64url(body.replace(/\+/g, '-').replace(/\//g, '_'));
}
