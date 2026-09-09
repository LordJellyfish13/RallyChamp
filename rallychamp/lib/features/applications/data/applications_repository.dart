import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'staff_role.dart';

class ApplicationsRepository {
  ApplicationsRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Resolves the uid to write application data under. If [password] is
  /// given, creates a new email/password account. If null, the caller has
  /// already authenticated some other way (e.g. Google Sign-In) and we just
  /// use the currently signed-in user.
  Future<String> _resolveUid({required String email, String? password}) async {
    if (password != null) {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user!.uid;
    }
    final current = _auth.currentUser;
    if (current == null) {
      throw StateError('No authenticated user — sign in before submitting.');
    }
    return current.uid;
  }

  /// Files a marshal/judge application. Either creates a new email/password
  /// account ([password] given) or attaches to the already-signed-in user
  /// ([password] null, e.g. after Google Sign-In). See dev_notes.md §5 for
  /// why plain sign-up is the default rather than upgrading an anonymous
  /// session.
  Future<void> submitStaffApplication({
    required String rallyId,
    required StaffRole role,
    required String name,
    required String email,
    String? password,
    required String phone,
    required String oib,
    String? licenseNumber,
  }) async {
    final uid = await _resolveUid(email: email, password: password);

    final batch = _firestore.batch();
    batch.set(_firestore.collection('users').doc(uid), {
      'name': name,
      'email': email,
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
          .doc(uid),
      {
        'roleRequested': role.firestoreValue,
        'status': 'pending',
        'assignedCheckpointId': null,
        'appliedAt': FieldValue.serverTimestamp(),
      },
    );
    await batch.commit();
  }

  /// Creates a real account and files a team/competitor entry. Entry data
  /// is split public (`entries/{uid}`) vs private (`entries/{uid}/private/
  /// contact`) because entry lists are meant to be publicly browsable
  /// (car number, class, team name) while contact info never should be —
  /// see dev_notes.md §9 on why public/private never share a document.
  Future<void> submitTeamEntry({
    required String rallyId,
    required String teamName,
    required String driverName,
    required String carNumber,
    required String carClass,
    required String email,
    String? password,
    required String phone,
    required String oib,
  }) async {
    final uid = await _resolveUid(email: email, password: password);

    final batch = _firestore.batch();
    batch.set(_firestore.collection('users').doc(uid), {
      'name': driverName,
      'email': email,
      'phone': phone,
      'oib': oib,
      'licenseNumber': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final entryRef = _firestore
        .collection('rallies')
        .doc(rallyId)
        .collection('entries')
        .doc(uid);
    batch.set(entryRef, {
      'teamName': teamName,
      'driverName': driverName,
      'carNumber': carNumber,
      'class': carClass,
      'status': 'pending',
      'appliedAt': FieldValue.serverTimestamp(),
    });
    batch.set(entryRef.collection('private').doc('contact'), {
      'phone': phone,
      'oib': oib,
      'email': email,
    });

    await batch.commit();
  }
}
