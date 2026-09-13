import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'stage_result.dart';

class ResultsRepository {
  ResultsRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Every result for a rally, in one listener. Flat with a `stageId`
  /// field rather than nested per stage (dev_notes.md §9) precisely so the
  /// results screen can switch between stages and the overall standings
  /// without opening a new subscription each time.
  Stream<List<StageResult>> watchResults(String rallyId) {
    return _firestore
        .collection('rallies')
        .doc(rallyId)
        .collection('results')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(StageResult.fromFirestore).toList(),
        );
  }

  /// Records one crew's run down one stage.
  ///
  /// The document id is `{stageId}_{entryId}` rather than auto-generated,
  /// which is what makes this idempotent (§9): race control is typing on a
  /// phone with bad signal, and a retry after a dropped connection has to
  /// overwrite the same row instead of quietly creating a second one.
  Future<void> saveResult({
    required String rallyId,
    required String stageId,
    required String entryId,
    required String carNumber,
    required ResultStatus status,
    int? timeMs,
  }) {
    return _firestore
        .collection('rallies')
        .doc(rallyId)
        .collection('results')
        .doc('${stageId}_$entryId')
        .set({
          'stageId': stageId,
          'entryId': entryId,
          'carNumber': carNumber,
          'status': status.firestoreValue,
          'timeMs': status == ResultStatus.finished ? timeMs : null,
          'source': ResultSource.manual.firestoreValue,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': _auth.currentUser?.uid,
        });
  }

  /// Removes a result typed against the wrong car — the one correction
  /// that overwriting can't make, since the wrong row would otherwise sit
  /// in the standings forever.
  Future<void> deleteResult({
    required String rallyId,
    required String stageId,
    required String entryId,
  }) {
    return _firestore
        .collection('rallies')
        .doc(rallyId)
        .collection('results')
        .doc('${stageId}_$entryId')
        .delete();
  }
}
