import 'package:cloud_firestore/cloud_firestore.dart';

import 'staff_role.dart';

StaffRole _roleFromFirestore(String? value) {
  return value == 'judge' ? StaffRole.judge : StaffRole.marshal;
}

class StaffApplicationSummary {
  const StaffApplicationSummary({
    required this.uid,
    required this.role,
    required this.status,
    required this.applicantName,
    required this.applicantPhone,
    required this.assignedCheckpointId,
    required this.appliedAt,
  });

  factory StaffApplicationSummary.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return StaffApplicationSummary(
      uid: doc.id,
      role: _roleFromFirestore(data['roleRequested'] as String?),
      status: data['status'] as String? ?? 'pending',
      applicantName: data['applicantName'] as String? ?? '',
      applicantPhone: data['applicantPhone'] as String? ?? '',
      assignedCheckpointId: data['assignedCheckpointId'] as String?,
      appliedAt: (data['appliedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  final String uid;
  final StaffRole role;
  final String status;
  final String applicantName;
  final String applicantPhone;
  final String? assignedCheckpointId;
  final DateTime appliedAt;

  bool get isPending => status == 'pending';
}
