import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Where the push endpoint lives once it's deployed (see
/// `push-endpoint/README.md`). Not a secret — it's a public URL guarded by
/// the Firebase ID token every call carries.
///
/// Empty until deployed, and everything degrades quietly when it is:
/// events are still logged and the app works exactly as before, there's
/// just nothing telling anyone's phone about them.
const pushEndpointUrl = '';

/// Asks the endpoint to push a freshly-written event.
///
/// Deliberately swallows every failure. This runs right after a status
/// change at a rally, where no signal is the normal case — the write
/// itself is already safely queued by Firestore, and an organizer who just
/// tapped "Pause" should not get an error dialog about push delivery.
/// That is the accepted cost of the card-free endpoint over a Cloud
/// Function: the log is reliable, the push is best-effort.
///
/// The endpoint decides what's actually worth sending by reading the event
/// back from Firestore — this only nominates a candidate, it can't dictate
/// the text or the channel.
Future<void> requestPush({
  required String rallyId,
  required String eventId,
}) async {
  if (pushEndpointUrl.isEmpty) return;

  try {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) return;

    await http
        .post(
          Uri.parse(pushEndpointUrl),
          headers: {
            'authorization': 'Bearer $token',
            'content-type': 'application/json',
          },
          body: jsonEncode({'rallyId': rallyId, 'eventId': eventId}),
        )
        .timeout(const Duration(seconds: 5));
  } catch (_) {
    // Intentionally ignored — see the doc comment.
  }
}
