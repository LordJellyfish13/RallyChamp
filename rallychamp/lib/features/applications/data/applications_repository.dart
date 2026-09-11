import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'staff_application_summary.dart';
import 'staff_role.dart';

/// Rally statuses under which the event is genuinely happening right now —
/// as opposed to 'setup' (not started) or 'stopped' (over). Used to decide
/// whether a walk-up marshal application can be auto-accepted. Mirrored in
/// firestore.rules, which is the actual enforcement — this copy is just so
/// the client can compute the same answer for a smooth UX instead of
/// guessing and having the write rejected.
const _liveRallyStatuses = {'running', 'start', 'paused', 'lunch break'};

/// Applying always happens from an already-signed-in session now — the
/// caller pushes `LoginPage` (via `ensureSignedIn`) first. This repository
/// no longer creates accounts itself; see dev_notes.md §5 "A real login
/// page" for why that used to be duplicated per-form and caused a real bug
/// (applying silently switched which account the whole app was signed in
/// as).
class ApplicationsRepository {
  ApplicationsRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  User _requireCurrentUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user — sign in before submitting.');
    }
    return user;
  }

  /// Files a marshal/judge application for the signed-in user.
  ///
  /// `applicantName`/`applicantPhone` are denormalized onto the application
  /// document itself so an organizer reviewing it doesn't need read access
  /// to `users/{uid}` (which stays self-only) — see dev_notes.md §5.
  ///
  /// A marshal application (never judge — judges need real vetting) is
  /// auto-accepted if the rally is currently live and its organizer has
  /// left walk-up marshals enabled — see dev_notes.md §5 "Walk-up marshals
  /// during a live rally". This is only the client's best guess for a
  /// smooth UX; `firestore.rules` independently re-checks the same
  /// conditions server-side before allowing the write.
  Future<void> submitStaffApplication({
    required String rallyId,
    required StaffRole role,
    required String name,
    required String phone,
    required String oib,
    String? licenseNumber,
  }) async {
    final user = _requireCurrentUser();
    final status = await _resolveInitialStaffStatus(
      rallyId: rallyId,
      role: role,
    );

    final batch = _firestore.batch();
    batch.set(_firestore.collection('users').doc(user.uid), {
      'name': name,
      'email': user.email,
      'phone': phone,
      'oib': oib,
      'licenseNumber': licenseNumber,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _firestore
          .collection('rallies')
          .doc(rallyId)
          .collection('staffApplications')
          .doc(user.uid),
      {
        'roleRequested': role.firestoreValue,
        'status': status,
        'applicantName': name,
        'applicantPhone': phone,
        'assignedCheckpointId': null,
        'appliedAt': FieldValue.serverTimestamp(),
      },
    );
    await batch.commit();
  }

  Future<String> _resolveInitialStaffStatus({
    required String rallyId,
    required StaffRole role,
  }) async {
    if (role != StaffRole.marshal) return 'pending';
    final rallyDoc = await _firestore.collection('rallies').doc(rallyId).get();
    final data = rallyDoc.data();
    if (data == null) return 'pending';
    final allowWalkup = data['allowWalkupMarshals'] as bool? ?? false;
    final rallyStatus = data['status'] as String?;
    if (allowWalkup && _liveRallyStatuses.contains(rallyStatus)) {
      return 'accepted';
    }
    return 'pending';
  }

  /// Applications for a rally, for its organizers to review. Sorted
  /// pending-first client-side rather than via `.orderBy()`, same reasoning
  /// as `RallyRepository.watchMyRallies()`.
  Stream<List<StaffApplicationSummary>> watchStaffApplications(
    String rallyId,
  ) {
    return _firestore
        .collection('rallies')
        .doc(rallyId)
        .collection('staffApplications')
        .snapshots()
        .map((snapshot) {
          final applications = snapshot.docs
              .map(StaffApplicationSummary.fromFirestore)
              .toList();
          applications.sort((a, b) {
            if (a.isPending != b.isPending) return a.isPending ? -1 : 1;
            return b.appliedAt.compareTo(a.appliedAt);
          });
          return applications;
        });
  }

  /// Accepts or rejects a pending application, optionally assigning a
  /// checkpoint at the same time. Organizer-only — enforced by
  /// firestore.rules checking the rally's adminUids.
  Future<void> reviewStaffApplication({
    required String rallyId,
    required String uid,
    required bool accept,
    String? assignedCheckpointId,
  }) {
    return _firestore
        .collection('rallies')
        .doc(rallyId)
        .collection('staffApplications')
        .doc(uid)
        .update({
          'status': accept ? 'accepted' : 'rejected',
          'assignedCheckpointId': accept ? assignedCheckpointId : null,
        });
  }

  /// Files a team/competitor entry for the signed-in user. Entry data is
  /// split public (`entries/{uid}`) vs private (`entries/{uid}/private/
  /// contact`) because entry lists are meant to be publicly browsable
  /// (car number, class, team name) while contact info never should be —
  /// see dev_notes.md §9 on why public/private never share a document.
  Future<void> submitTeamEntry({
    required String rallyId,
    required String teamName,
    required String driverName,
    required String coDriverName,
    required String carNumber,
    required String carClass,
    required String phone,
    required String oib,
  }) async {
    final user = _requireCurrentUser();

    final batch = _firestore.batch();
    batch.set(_firestore.collection('users').doc(user.uid), {
      'name': driverName,
      'email': user.email,
      'phone': phone,
      'oib': oib,
      'licenseNumber': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final entryRef = _firestore
        .collection('rallies')
        .doc(rallyId)
        .collection('entries')
        .doc(user.uid);
    batch.set(entryRef, {
      'teamName': teamName,
      'driverName': driverName,
      'coDriverName': coDriverName,
      'carNumber': carNumber,
      'class': carClass,
      'status': 'pending',
      'appliedAt': FieldValue.serverTimestamp(),
    });
    batch.set(entryRef.collection('private').doc('contact'), {
      'phone': phone,
      'oib': oib,
      'email': user.email,
    });

    await batch.commit();
  }
}
