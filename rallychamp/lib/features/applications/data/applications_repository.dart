import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'staff_role.dart';

class ApplicationsRepository {
  ApplicationsRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Creates a real account (email/password) and files a marshal/judge
  /// application in one go. See dev_notes.md §5 for why this is a plain
  /// sign-up rather than upgrading an anonymous session for now.
  Future<void> submitStaffApplication({
    required String rallyId,
    required StaffRole role,
    required String name,
    required String email,
    required String password,
    required String phone,
    required String oib,
    String? licenseNumber,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;

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
    required String password,
    required String phone,
    required String oib,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;

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
