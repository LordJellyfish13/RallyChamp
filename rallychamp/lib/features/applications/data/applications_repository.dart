import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../entries/data/entry.dart';
import 'staff_application_summary.dart';
import 'staff_role.dart';
import 'user_profile.dart';

/// Rally statuses under which the event is genuinely happening right now —
/// as opposed to 'setup' (not started) or 'stopped' (over). Used to decide
/// whether a walk-up marshal application can be auto-accepted, and whether
/// the Status page's on-duty assignment banner should show. Mirrored in
/// firestore.rules, which is the actual enforcement for the walk-up-marshal
/// case — this copy is just so the client can compute the same answer for a
/// smooth UX instead of guessing and having the write rejected. Deliberately
/// includes 'start' (unlike `RallyDisplayStatus.active`, the spectator-
/// facing "Active" label, which buckets 'start' as "Upcoming") — a marshal
/// should already be considered on duty once the rally has been started,
/// even before it reaches 'running'.
const liveRallyStatuses = {'running', 'start', 'paused', 'lunch break'};

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

  /// The signed-in user's own `users/{uid}` document, if one exists yet —
  /// null on a first-ever application, before either form has written one.
  /// Both application forms call this to prefill themselves: see
  /// dev_notes.md §5 "Don't retype what's already known".
  ///
  /// Same timeout-then-cache-fallback shape as `RallyRepository
  /// .getRallySummary`, for the same reason: a form opening on a cold
  /// start with no signal shouldn't sit waiting on a network read before
  /// showing itself, when a perfectly good cached profile is sitting
  /// right there.
  Future<UserProfile?> getMyProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final ref = _firestore.collection('users').doc(uid);
    try {
      final doc = await ref.get().timeout(const Duration(seconds: 3));
      if (!doc.exists) return null;
      return UserProfile.fromFirestore(doc);
    } catch (_) {
      try {
        final cached = await ref.get(const GetOptions(source: Source.cache));
        if (!cached.exists) return null;
        return UserProfile.fromFirestore(cached);
      } catch (_) {
        return null;
      }
    }
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
    if (allowWalkup && liveRallyStatuses.contains(rallyStatus)) {
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

  /// Accepted marshals/judges for a rally, for the People roster — visible
  /// to that rally's admins and to any other accepted staff member (see
  /// firestore.rules: an accepted doc is peer-readable by another accepted
  /// peer). Queries only `status == 'accepted'`, not every application,
  /// both because that's the actual "who's working this rally" roster and
  /// because the peer-read security rule only grants access to accepted
  /// docs — a `list` fails entirely if any matched document wouldn't pass
  /// the rule, so the query and the rule have to agree on this filter.
  Stream<List<StaffApplicationSummary>> watchAcceptedStaff(String rallyId) {
    return _firestore
        .collection('rallies')
        .doc(rallyId)
        .collection('staffApplications')
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(StaffApplicationSummary.fromFirestore).toList(),
        );
  }

  /// The signed-in user's own staff application for [rallyId] — null if
  /// they never applied, or aren't signed in. Powers the Status page's
  /// on-duty assignment banner. Purely self-access, so no rule change was
  /// needed beyond what already existed.
  Stream<StaffApplicationSummary?> watchMyStaffApplication(String rallyId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _firestore
        .collection('rallies')
        .doc(rallyId)
        .collection('staffApplications')
        .doc(uid)
        .snapshots()
        .map(
          (doc) => doc.exists ? StaffApplicationSummary.fromFirestore(doc) : null,
        );
  }

  /// A rally's entries, ordered the way a start list reads. Kept on this
  /// repository rather than a new one because it already owns every write
  /// to `entries` — one collection, one place that talks to it.
  ///
  /// Sorted client-side: pending first for the organizer reviewing them,
  /// then by car number. Doing it in Firestore would need a composite
  /// index for a list that's a few dozen rows at club scale.
  Stream<List<Entry>> watchEntries(String rallyId) {
    return _firestore
        .collection('rallies')
        .doc(rallyId)
        .collection('entries')
        .snapshots()
        .map((snapshot) {
          final entries = snapshot.docs.map(Entry.fromFirestore).toList();
          entries.sort((a, b) {
            if (a.isPending != b.isPending) return a.isPending ? -1 : 1;
            return compareCarNumbers(a.carNumber, b.carNumber);
          });
          return entries;
        });
  }

  /// Accepts or rejects an entry. Organizer-only, and `firestore.rules`
  /// narrows the write to `status` alone so nothing else on a competitor's
  /// entry can be altered.
  Future<void> reviewEntry({
    required String rallyId,
    required String entryId,
    required bool accept,
  }) {
    return _firestore
        .collection('rallies')
        .doc(rallyId)
        .collection('entries')
        .doc(entryId)
        .update({
          'status': accept
              ? EntryStatus.accepted.firestoreValue
              : EntryStatus.rejected.firestoreValue,
        });
  }

  /// One entry's phone/email, from the admin-only subdocument. Fetched on
  /// demand rather than alongside the list: it's one read per entry, and
  /// an organizer only needs it for the competitor they're actually trying
  /// to reach.
  Future<EntryContact?> getEntryContact({
    required String rallyId,
    required String entryId,
  }) async {
    try {
      final doc = await _firestore
          .collection('rallies')
          .doc(rallyId)
          .collection('entries')
          .doc(entryId)
          .collection('private')
          .doc('contact')
          .get();
      return doc.exists ? EntryContact.fromFirestore(doc) : null;
    } catch (_) {
      return null;
    }
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
        // Auto-id, not the entrant's uid: a club almost always runs more
        // than one crew, and keying by account capped each person at a
        // single entry per rally — a team manager entering a second car
        // got an opaque permission error, because a `set()` on an existing
        // document evaluates as an *update*. Ownership therefore lives in
        // the `uid` field below rather than in the document path, and
        // `firestore.rules` checks that field on both documents.
        .doc();
    batch.set(entryRef, {
      'uid': user.uid,
      'teamName': teamName,
      'driverName': driverName,
      'coDriverName': coDriverName,
      'carNumber': carNumber,
      'class': carClass,
      'status': 'pending',
      'appliedAt': FieldValue.serverTimestamp(),
    });
    // Carries `uid` too, so its rules can identify the owner without a
    // `get()` on the parent entry — which wouldn't work anyway, since a
    // `get()` inside a batch can't see a sibling document being created in
    // that same batch (see `RallyRepository.createRally`).
    batch.set(entryRef.collection('private').doc('contact'), {
      'uid': user.uid,
      'phone': phone,
      'oib': oib,
      'email': user.email,
    });

    await batch.commit();
  }
}
