import 'package:cloud_firestore/cloud_firestore.dart';

class RallySummary {
  const RallySummary({
    required this.id,
    required this.name,
    required this.description,
    required this.visibility,
    required this.status,
    required this.createdAt,
  });

  factory RallySummary.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return RallySummary(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      visibility: data['visibility'] as String? ?? 'draft',
      status: data['status'] as String? ?? 'setup',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  final String id;
  final String name;
  final String description;
  final String visibility;
  final String status;
  final DateTime createdAt;

  bool get isDraft => visibility == 'draft';
}
