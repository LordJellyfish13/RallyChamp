import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../rallies/data/rally_event.dart';
import 'incident.dart';

class IncidentRepository {
  IncidentRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Files a report and announces it, in one batch: the detailed
  /// `incidents/{id}` document only staff can read, and the softened
  /// public `events` row that tells everyone else something happened.
  /// Both or neither — an alert with no report behind it, or a report
  /// nobody is told about, would each be worse than failing outright.
  ///
  /// Returns the event id so the caller can nominate it for a push.
  ///
  /// Deliberately has no photo step. dev_notes.md §5 originally called
  /// photos required, but requiring one *before submit* puts a camera
  /// between a marshal and an emergency alert while they may be running
  /// toward the car. Photos belong on the incident afterwards — and are
  /// parked entirely for now, since Cloud Storage isn't enabled on the
  /// project and enabling it wants the Blaze plan.
  Future<({String incidentId, String eventId})> reportIncident({
    required String rallyId,
    required String reporterName,
    required String reporterPhone,
    required bool crewOk,
    required bool roadBlocked,
    required List<HelpKind> helpRequested,
    String? checkpointId,
    String? checkpointCode,
    GeoPoint? location,
    String? note,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in before reporting an incident.');
    }

    final rallyRef = _firestore.collection('rallies').doc(rallyId);
    final incidentRef = rallyRef.collection('incidents').doc();
    final eventRef = rallyRef.collection('events').doc();

    final batch = _firestore.batch();
    batch.set(incidentRef, {
      'reporterUid': uid,
      'reporterName': reporterName,
      'reporterPhone': reporterPhone,
      'crewOk': crewOk,
      'roadBlocked': roadBlocked,
      'helpRequested': helpRequested.map((h) => h.firestoreValue).toList(),
      'status': IncidentStatus.open.firestoreValue,
      'checkpointId': checkpointId,
      'location': location,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
      'resolvedAt': null,
      'resolvedBy': null,
    });
    batch.set(eventRef, {
      ...incidentOpenedEventData(
        incidentId: incidentRef.id,
        roadBlocked: roadBlocked,
        checkpointId: checkpointId,
        checkpointCode: checkpointCode,
      ),
      'estimatedEndAt': null,
      'actorUid': uid,
      // Client clock, like every other event — a report filed in a dead
      // zone has to land in the timeline where it actually happened, not
      // where it happened to sync. See `RallyRepository.updateRallyStatus`.
      'occurredAt': Timestamp.now(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    return (incidentId: incidentRef.id, eventId: eventRef.id);
  }

  /// Organizer marking help as dispatched, or the incident as over.
  /// Resolving also posts a public "resolved" row, so the people who saw
  /// the alert get told it ended — an alert with no all-clear is how a
  /// crowd stays worried about something that was sorted an hour ago.
  Future<String?> updateStatus({
    required String rallyId,
    required Incident incident,
    required IncidentStatus status,
    String? checkpointCode,
  }) async {
    final rallyRef = _firestore.collection('rallies').doc(rallyId);
    final incidentRef = rallyRef.collection('incidents').doc(incident.id);
    final resolving = status == IncidentStatus.resolved;

    if (!resolving) {
      await incidentRef.update({'status': status.firestoreValue});
      return null;
    }

    final eventRef = rallyRef.collection('events').doc();
    final batch = _firestore.batch();
    batch.update(incidentRef, {
      'status': status.firestoreValue,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': _auth.currentUser?.uid,
    });
    batch.set(eventRef, {
      ...incidentResolvedEventData(
        incidentId: incident.id,
        checkpointId: incident.checkpointId,
        checkpointCode: checkpointCode,
      ),
      'estimatedEndAt': null,
      'actorUid': _auth.currentUser?.uid,
      'occurredAt': Timestamp.now(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return eventRef.id;
  }

  /// A rally's incidents, newest first. Staff-only by security rule, so a
  /// spectator's client simply gets a permission error here and never
  /// renders the list — which is the intended outcome, not a bug.
  Stream<List<Incident>> watchIncidents(String rallyId) {
    return _firestore
        .collection('rallies')
        .doc(rallyId)
        .collection('incidents')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Incident.fromFirestore).toList());
  }

  Stream<Incident?> watchIncident(String rallyId, String incidentId) {
    return _firestore
        .collection('rallies')
        .doc(rallyId)
        .collection('incidents')
        .doc(incidentId)
        .snapshots()
        .map((doc) => doc.exists ? Incident.fromFirestore(doc) : null);
  }
}
