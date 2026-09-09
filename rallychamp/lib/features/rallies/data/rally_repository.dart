import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'rally_summary.dart';

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
      'isMultiStage': stageCount > 1,
      'visibility': publishImmediately ? 'published' : 'draft',
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
}
