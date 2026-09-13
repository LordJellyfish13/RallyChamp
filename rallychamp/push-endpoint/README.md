# RallyChamp push endpoint

Sends FCM messages for rally events. Exists because a phone cannot send to
an FCM topic — only something holding the project's service-account key
can, and that key must never ship inside the app.

Free tier, no card required. Cloudflare Workers is what this is written
for, but the code is plain `fetch` and would run on Vercel, Netlify or
Supabase Edge with a different wrapper.

## What it does

The client posts `{rallyId, eventId}` with its Firebase ID token. The
worker then:

1. verifies the ID token's signature against Google's published keys;
2. reads the **rally** document and checks the caller is in `adminUids`;
3. reads the **event** document and decides, from the stored fields,
   whether it's worth pushing — the client never supplies the notification
   text, so a tampered client can't put arbitrary words on every
   spectator's lock screen;
4. skips anything retracted, older than 10 minutes, or already sent;
5. sends to topic `rally_<rallyId>` on the loud channel for incidents and
   the quiet one for status changes.

Setup and lunch-break changes deliberately never push.

## Setup (one-time, needs your accounts)

```bash
npm install -g wrangler
wrangler login                      # opens a browser
```

Get the service-account key: Firebase Console → Project Settings →
Service accounts → **Generate new private key**. That downloads a JSON
file.

> ⚠️ That file is a master key to the whole Firebase project. Never commit
> it, never paste it into chat, and delete the download once it's stored
> as a secret below. It's already covered by `.gitignore`.

```bash
cd push-endpoint
wrangler secret put SERVICE_ACCOUNT_JSON   # paste the whole JSON, then Ctrl+D
wrangler deploy
```

Deploy prints a URL like `https://rallychamp-push.<you>.workers.dev`. Put
it in `lib/core/notifications/push_sender.dart` as `pushEndpointUrl`.
Until it's set, the app simply doesn't call anything — everything else
keeps working.

## Checking it works

```bash
wrangler tail        # live logs while you change a rally's status in the app
```

## Known limitation

Delivery is **best-effort**. A Worker can't watch Firestore, so the app
calls this after writing the event — and at a rally the write can succeed
offline (Firestore queues it) while this HTTP call fails. The event is
still logged; the push is what's lost. Moving to a Cloud Function would
make it automatic, at the cost of needing Firebase's Blaze plan.
