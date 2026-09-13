import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

import 'checkpoint.dart';
import 'rally_event.dart';
import 'rally_summary.dart';
import 'stage.dart';

class RallyRepository {
  RallyRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Creates a rally (+ its default stage(s)) and, if [publishImmediately]
  /// is true, publishes it and posts a matching news entry. A rally always
  /// gets at least one stage document even when [stageCount] is 1, so
  /// downstream screens never need two code paths depending on whether a
  /// rally is "multi-stage" — see dev_notes.md §9.
  ///
  /// This is two sequential writes, not one atomic batch: the stage/news
  /// security rules `get()` the parent rally document to check admin
  /// access, and a `get()` inside a batch only sees the database as it was
  /// *before* the batch runs — it can't see a rally doc being created in
  /// that same batch. So the rally has to actually exist first.
  Future<String> createRally({
    required String name,
    required String description,
    required String locationName,
    required DateTime startDate,
    required DateTime endDate,
    required int stageCount,
    required bool publishImmediately,
    bool allowWalkupMarshals = true,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in before creating a rally.');
    }

    final rallyRef = _firestore.collection('rallies').doc();

    await rallyRef.set({
      'name': name,
      'description': description,
      'locationName': locationName,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': 'setup',
      // §9 lists an `isMultiStage` flag here. Deliberately not written:
      // it's derived from the stage count at this one moment, so it goes
      // stale the instant a stage is added or removed, and the `stages`
      // subcollection is the authoritative answer anyway. Nothing read it
      // — not a screen, not a rule — so it was pure stale-data risk. (A
      // rule needing it would be the one good reason to denormalize,
      // since rules can't count a subcollection; none does.)
      'visibility': publishImmediately ? 'published' : 'draft',
      'allowWalkupMarshals': allowWalkupMarshals,
      'adminUids': [uid],
      'createdAt': FieldValue.serverTimestamp(),
    });

    final batch = _firestore.batch();

    for (var i = 0; i < stageCount; i++) {
      final stageRef = rallyRef.collection('stages').doc();
      batch.set(stageRef, {
        'name': stageCount > 1 ? 'Stage ${i + 1}' : 'Main stage',
        'order': i,
        'status': 'setup',
        'distanceKm': null,
        'scheduledStart': null,
        'route': <Map<String, double>>[],
      });
    }

    // Seeds the activity log so a brand-new rally's Status page has a real
    // first row instead of an empty feed. Safe in this batch for the same
    // reason the stages are: the rally document already exists by now.
    batch.set(rallyRef.collection('events').doc(), {
      ...statusChangeEventData('setup'),
      'estimatedEndAt': null,
      'actorUid': uid,
      'occurredAt': Timestamp.now(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (publishImmediately) {
      final newsRef = _firestore.collection('news').doc();
      batch.set(newsRef, {
        'rallyId': rallyRef.id,
        'type': 'new_rally',
        'title': name,
        'body': description,
        'imageUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
        'authorUid': uid,
      });
    }

    await batch.commit();
    return rallyRef.id;
  }

  /// Rallies the signed-in user administers, newest first. Sorted
  /// client-side rather than via `.orderBy()` — combining an
  /// `array-contains` filter with an order-by on a different field needs a
  /// Firestore composite index, and this list is small enough (one
  /// organizer's own rallies) that it isn't worth the extra deploy step.
  Stream<List<RallySummary>> watchMyRallies() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection('rallies')
        .where('adminUids', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
          final rallies = snapshot.docs.map(RallySummary.fromFirestore).toList();
          rallies.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return rallies;
        });
  }

  /// Publishes an existing draft rally and posts a matching news entry.
  /// Unlike `createRally`, this can be one atomic batch: the rally document
  /// already exists before this batch runs, so the news-creation rule's
  /// `get()` on it resolves correctly (see `createRally`'s doc comment for
  /// the case where that doesn't hold).
  Future<void> publishRally({
    required String rallyId,
    required String name,
    required String description,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in before publishing a rally.');
    }

    final batch = _firestore.batch();
    batch.update(_firestore.collection('rallies').doc(rallyId), {
      'visibility': 'published',
    });
    batch.set(_firestore.collection('news').doc(), {
      'rallyId': rallyId,
      'type': 'new_rally',
      'title': name,
      'body': description,
      'imageUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
      'authorUid': uid,
    });
    await batch.commit();
  }

  /// Rewrites the rally's descriptive fields. Deliberately narrow: it
  /// touches only what the edit screen shows, so `status`, `visibility`,
  /// `adminUids` and `isMultiStage` can't be changed by accident from
  /// here. Each of those has its own deliberate path — the Status page's
  /// status control, `publishRally`, and the Stages page — and a details
  /// form quietly rewriting them would be a nasty surprise.
  ///
  /// [organizerPhone] is cleared (written as null) when blank, so an
  /// organizer can take their number back down again.
  Future<void> updateRallyDetails({
    required String rallyId,
    required String name,
    required String description,
    required String locationName,
    required DateTime startDate,
    required DateTime endDate,
    required bool allowWalkupMarshals,
    String? organizerPhone,
  }) async {
    final trimmedPhone = organizerPhone?.trim();
    await _firestore.collection('rallies').doc(rallyId).update({
      'name': name,
      'description': description,
      'locationName': locationName,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'allowWalkupMarshals': allowWalkupMarshals,
      'organizerPhone': (trimmedPhone == null || trimmedPhone.isEmpty)
          ? null
          : trimmedPhone,
    });
  }

  /// A single rally by id, for the active-rally switcher — returns null if
  /// it doesn't exist, or isn't readable (unpublished and we're not an
  /// admin), rather than throwing, so the switcher can just skip it.
  ///
  /// Falls back to an explicit cache-only read when the network attempt
  /// fails or is slow: a cold app start with no signal doesn't give the
  /// default server-then-cache `get()` a prior failed request to know it's
  /// offline from, so instead of failing fast it can sit for a long time
  /// before giving up on the network and throwing `unavailable` — and
  /// either way, quietly serving the (perfectly good) cached copy would
  /// otherwise make the whole active-rally switcher, and everything
  /// downstream of it (the Map tab most of all), look empty/stuck despite
  /// the rally being fully cached.
  Future<RallySummary?> getRallySummary(String rallyId) async {
    final ref = _firestore.collection('rallies').doc(rallyId);
    try {
      final doc = await ref.get().timeout(const Duration(seconds: 3));
      if (!doc.exists) return null;
      return RallySummary.fromFirestore(doc);
    } catch (_) {
      try {
        final cached = await ref.get(const GetOptions(source: Source.cache));
        if (!cached.exists) return null;
        return RallySummary.fromFirestore(cached);
      } catch (_) {
        return null;
      }
    }
  }

  /// Live updates for a single rally — unlike [getRallySummary], this is a
  /// `snapshots()` stream, not a one-shot read: it's what backs the Status
  /// page's status display and the organizer's status control, both of
  /// which need to reflect a status change within moments of it happening,
  /// for everyone currently looking at the page — not just on next visit.
  /// No timeout/cache-fallback dance needed here the way [getRallySummary]
  /// needs one: Firestore's offline persistence already serves a stream's
  /// cached value immediately, which is the whole point of using a stream.
  Stream<RallySummary?> watchRallySummary(String rallyId) {
    return _firestore
        .collection('rallies')
        .doc(rallyId)
        .snapshots()
        .map((doc) => doc.exists ? RallySummary.fromFirestore(doc) : null);
  }

  /// Sets a rally's live status (setup/start/running/paused/lunch break/
  /// stopped) — the organizer's "Start"-and-beyond control on the Status
  /// page (see dev_notes.md §5 "Rally going live"). Free-form rather than a
  /// constrained state machine: real rallies pause and resume more than
  /// once, so a strict linear sequence would fight the organizer more than
  /// it would protect them.
  ///
  /// Writes two things in one batch: the `status` field (which other things
  /// already depend on — `firestore.rules` reads it directly to decide
  /// walk-up-marshal auto-accept, and rules can't query "latest doc in a
  /// subcollection", which is why the field stays rather than the log
  /// becoming the single source of truth) and an immutable event row for
  /// the activity log. Safe as one batch, unlike `createRally`: the events
  /// rule `get()`s the rally document, and that already exists here.
  ///
  /// [estimatedEndAt] is the optional "back by ~" an organizer can set when
  /// pausing — genuinely useful to a marshal standing in a field with no
  /// idea how long the hold is.
  /// Returns the new event's id, so the caller can ask the push endpoint
  /// to announce it (see `core/notifications/push_sender.dart`) — the id
  /// is generated client-side, before the write is acknowledged.
  Future<String> updateRallyStatus({
    required String rallyId,
    required String status,
    DateTime? estimatedEndAt,
  }) async {
    final rallyRef = _firestore.collection('rallies').doc(rallyId);
    final eventRef = rallyRef.collection('events').doc();
    final batch = _firestore.batch();
    batch.update(rallyRef, {'status': status});
    batch.set(eventRef, {
      ...statusChangeEventData(status),
      'estimatedEndAt': estimatedEndAt == null
          ? null
          : Timestamp.fromDate(estimatedEndAt),
      'actorUid': _auth.currentUser?.uid,
      // `occurredAt` is the client's clock and is what the feed sorts by;
      // `createdAt` is the server's, kept for auditing. In a dead zone a
      // queued write resolves its server timestamp whenever it finally
      // syncs — possibly much later — which would drop the event into the
      // wrong place in a timeline that's supposed to say when things
      // actually happened. Offline is the normal case for this app, not
      // an edge case.
      'occurredAt': Timestamp.now(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return eventRef.id;
  }

  /// Moves one stage through its own lifecycle, and logs it. Mirrors
  /// `updateRallyStatus` exactly — same batch-of-two shape, same
  /// client-clock `occurredAt`, same returned event id for the push
  /// endpoint — because it's the same kind of announcement, just scoped to
  /// one road rather than the whole event.
  ///
  /// [stageName] is passed in rather than read back here so the name gets
  /// frozen into the event's title at write time: renaming a stage later
  /// must not rewrite what the log already said about it.
  Future<String> updateStageStatus({
    required String rallyId,
    required String stageId,
    required String stageName,
    required StageStatus status,
  }) async {
    final rallyRef = _firestore.collection('rallies').doc(rallyId);
    final eventRef = rallyRef.collection('events').doc();
    final batch = _firestore.batch();
    batch.update(rallyRef.collection('stages').doc(stageId), {
      'status': status.firestoreValue,
    });
    batch.set(eventRef, {
      ...stageStatusEventData(
        stageId: stageId,
        stageName: stageName,
        status: status.firestoreValue,
      ),
      'estimatedEndAt': null,
      'actorUid': _auth.currentUser?.uid,
      'occurredAt': Timestamp.now(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return eventRef.id;
  }

  /// Sets a stage's start time, and an *override* of its length — the two
  /// fields §9 always specified and `createRally` has always seeded as
  /// null. [distanceKm] is deliberately an override, not the length
  /// itself: `Stage.effectiveDistanceKm` already measures the drawn route
  /// automatically, so this only needs writing when the published figure
  /// differs from that measurement.
  ///
  /// Both are nullable and written even when null, so an organizer can
  /// clear a figure they got wrong — [distanceKm] going back to null
  /// simply means the measured route length takes over again, not that
  /// the stage loses its length entirely.
  ///
  /// Unlike a status change this writes no activity-log event: a
  /// timetable being filled in during setup isn't news, and logging every
  /// correction would bury the entries that matter.
  Future<void> updateStageDetails({
    required String rallyId,
    required String stageId,
    double? distanceKm,
    DateTime? scheduledStart,
  }) {
    return _firestore
        .collection('rallies')
        .doc(rallyId)
        .collection('stages')
        .doc(stageId)
        .update({
          'distanceKm': distanceKm,
          'scheduledStart': scheduledStart == null
              ? null
              : Timestamp.fromDate(scheduledStart),
        });
  }

  /// Withdraws a log entry an organizer logged by mistake. Writes only
  /// `retractedAt`/`retractedBy`, which is all `firestore.rules` lets an
  /// update touch — the entry's own label, title and time stay exactly as
  /// written, and nothing can delete it.
  ///
  /// The timestamp is the client's, not `serverTimestamp()`, for a reason
  /// that bites specifically offline: a server timestamp reads back as
  /// null locally until the write syncs, so an organizer retracting a row
  /// in a dead zone would tap it and watch nothing happen.
  Future<void> retractEvent({
    required String rallyId,
    required String eventId,
  }) {
    return _firestore
        .collection('rallies')
        .doc(rallyId)
        .collection('events')
        .doc(eventId)
        .update({
          'retractedAt': Timestamp.now(),
          'retractedBy': _auth.currentUser?.uid,
        });
  }

  /// A rally's activity log, newest first — the Status page feed. Capped
  /// because nobody scrolls past a day of a rally's events, and an
  /// unbounded listener on a long event is wasted battery and data.
  /// Ordering on a single field needs no composite index.
  Stream<List<RallyEvent>> watchEvents(String rallyId, {int limit = 50}) {
    return _firestore
        .collection('rallies')
        .doc(rallyId)
        .collection('events')
        .orderBy('occurredAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(RallyEvent.fromFirestore).toList());
  }

  /// A single checkpoint by id — resolves an accepted staff member's
  /// assignment for the People roster and the Status page's on-duty
  /// banner. Same timeout + cache-fallback shape as [getRallySummary], for
  /// the same reason: this can run on a cold, offline app start too.
  Future<Checkpoint?> getCheckpoint(String rallyId, String checkpointId) async {
    final ref = _firestore
        .collection('rallies')
        .doc(rallyId)
        .collection('checkpoints')
        .doc(checkpointId);
    try {
      final doc = await ref.get().timeout(const Duration(seconds: 3));
      if (!doc.exists) return null;
      return Checkpoint.fromFirestore(doc);
    } catch (_) {
      try {
        final cached = await ref.get(const GetOptions(source: Source.cache));
        if (!cached.exists) return null;
        return Checkpoint.fromFirestore(cached);
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> createCheckpoint({
    required String rallyId,
    required String code,
    required CheckpointKind kind,
    String? stageId,
    GeoPoint? location,
  }) {
    return _firestore
        .collection('rallies')
        .doc(rallyId)
        .collection('checkpoints')
        .add({
          'code': code,
          'kind': kind.firestoreValue,
          'stageId': stageId,
          'location': location,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> updateCheckpoint({
    required String rallyId,
    required String checkpointId,
    required String code,
    required CheckpointKind kind,
    String? stageId,
    GeoPoint? location,
  }) {
    return _firestore
        .collection('rallies')
        .doc(rallyId)
        .collection('checkpoints')
        .doc(checkpointId)
        .update({
          'code': code,
          'kind': kind.firestoreValue,
          'stageId': stageId,
          'location': location,
        });
  }

  Future<void> deleteCheckpoint({
    required String rallyId,
    required String checkpointId,
  }) {
    return _firestore
        .collection('rallies')
        .doc(rallyId)
        .collection('checkpoints')
        .doc(checkpointId)
        .delete();
  }

  /// Sorted client-side by code — a rally's checkpoint count is small
  /// enough that this doesn't need a server-side `.orderBy()`.
  Stream<List<Checkpoint>> watchCheckpoints(String rallyId) {
    return _firestore
        .collection('rallies')
        .doc(rallyId)
        .collection('checkpoints')
        .snapshots()
        .map((snapshot) {
          final checkpoints = snapshot.docs
              .map(Checkpoint.fromFirestore)
              .toList();
          checkpoints.sort((a, b) => a.code.compareTo(b.code));
          return checkpoints;
        });
  }

  /// Sorted client-side by `order` — a rally's stage count is small enough
  /// that this doesn't need a server-side `.orderBy()`.
  Stream<List<Stage>> watchStages(String rallyId) {
    return _firestore
        .collection('rallies')
        .doc(rallyId)
        .collection('stages')
        .snapshots()
        .map((snapshot) {
          final stages = snapshot.docs.map(Stage.fromFirestore).toList();
          stages.sort((a, b) => a.order.compareTo(b.order));
          return stages;
        });
  }

  /// Overwrites a stage's route — either from manually dropped points or a
  /// GPS recording (see dev_notes.md §5 "Route creation"). Stored as plain
  /// `{lat, lng}` maps, matching the schema `createRally` already writes
  /// (an empty list of the same shape), not `GeoPoint` — unlike checkpoint
  /// locations, this predates this feature and there was no reason to
  /// change it.
  Future<void> updateStageRoute({
    required String rallyId,
    required String stageId,
    required List<LatLng> route,
  }) {
    return _firestore
        .collection('rallies')
        .doc(rallyId)
        .collection('stages')
        .doc(stageId)
        .update({
          'route': route
              .map((p) => {'lat': p.latitude, 'lng': p.longitude})
              .toList(),
        });
  }
}
