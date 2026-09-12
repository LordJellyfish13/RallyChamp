import 'package:cloud_firestore/cloud_firestore.dart';

/// A simplified, spectator-friendly lifecycle bucket derived from the
/// rally's real `status` (setup/start/running/paused/lunch break/stopped)
/// — see dev_notes.md §5 "Rally status display" for why this is computed,
/// not a second stored field: the real `status` already drives walk-up-
/// marshal auto-accept and the Status page, so it stays the single source
/// of truth.
enum RallyDisplayStatus { upcoming, active, finished }

extension RallyDisplayStatusX on RallyDisplayStatus {
  String get label => switch (this) {
    RallyDisplayStatus.upcoming => 'Upcoming',
    RallyDisplayStatus.active => 'Active',
    RallyDisplayStatus.finished => 'Finished',
  };
}

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

  RallyDisplayStatus get displayStatus => switch (status) {
    'running' || 'paused' || 'lunch break' => RallyDisplayStatus.active,
    'stopped' => RallyDisplayStatus.finished,
    _ => RallyDisplayStatus.upcoming, // setup, start, or anything unknown
  };
}
