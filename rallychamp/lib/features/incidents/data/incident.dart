import 'package:cloud_firestore/cloud_firestore.dart';

/// Who the reporter is asking for. Matches the §9 schema — deliberately a
/// short fixed list rather than free text, because this is read by someone
/// deciding what to dispatch, in a hurry.
enum HelpKind { marshal, ambulance, firefighter }

extension HelpKindX on HelpKind {
  String get firestoreValue => switch (this) {
    HelpKind.marshal => 'marshal',
    HelpKind.ambulance => 'ambulance',
    HelpKind.firefighter => 'firefighter',
  };

  String get label => switch (this) {
    HelpKind.marshal => 'More marshals',
    HelpKind.ambulance => 'Ambulance',
    HelpKind.firefighter => 'Firefighters',
  };
}

HelpKind? _helpFromFirestore(String value) => switch (value) {
  'marshal' => HelpKind.marshal,
  'ambulance' => HelpKind.ambulance,
  'firefighter' => HelpKind.firefighter,
  _ => null,
};

/// open → responding → resolved. `responding` earns its place: it's the
/// difference between the marshal standing at the scene knowing help is
/// coming and wondering whether anyone saw the report at all.
enum IncidentStatus { open, responding, resolved }

extension IncidentStatusX on IncidentStatus {
  String get firestoreValue => switch (this) {
    IncidentStatus.open => 'open',
    IncidentStatus.responding => 'responding',
    IncidentStatus.resolved => 'resolved',
  };

  String get label => switch (this) {
    IncidentStatus.open => 'Open',
    IncidentStatus.responding => 'Help on the way',
    IncidentStatus.resolved => 'Resolved',
  };
}

IncidentStatus _statusFromFirestore(String? value) => switch (value) {
  'responding' => IncidentStatus.responding,
  'resolved' => IncidentStatus.resolved,
  _ => IncidentStatus.open,
};

/// A structured incident report — what replaces the informal Viber-group
/// crash photo and "anyone near R10?" (dev_notes.md §5). Readable only by
/// the rally's staff and organizers; the public activity feed carries a
/// deliberately vaguer row pointing at this.
class Incident {
  const Incident({
    required this.id,
    required this.reporterUid,
    required this.reporterName,
    required this.reporterPhone,
    required this.crewOk,
    required this.roadBlocked,
    required this.helpRequested,
    required this.status,
    required this.createdAt,
    this.checkpointId,
    this.location,
    this.note,
    this.resolvedAt,
  });

  factory Incident.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final help = (data['helpRequested'] as List<dynamic>? ?? const [])
        .map((value) => _helpFromFirestore(value as String))
        .nonNulls
        .toList();
    return Incident(
      id: doc.id,
      reporterUid: data['reporterUid'] as String? ?? '',
      reporterName: data['reporterName'] as String? ?? 'Unknown',
      reporterPhone: data['reporterPhone'] as String? ?? '',
      crewOk: data['crewOk'] as bool? ?? false,
      roadBlocked: data['roadBlocked'] as bool? ?? false,
      helpRequested: help,
      status: _statusFromFirestore(data['status'] as String?),
      checkpointId: data['checkpointId'] as String?,
      location: data['location'] as GeoPoint?,
      note: data['note'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String reporterUid;

  /// Denormalized at report time, like `staffApplications.applicantName`,
  /// so an organizer reading a report never needs access to `users/{uid}`
  /// (which holds OIB and stays self-access only — see dev_notes.md §3).
  final String reporterName;

  /// Denormalized for the same reason, and load-bearing here: an organizer
  /// reading a crash report needs to reach the person standing next to the
  /// car in one tap, not go hunting for their number.
  final String reporterPhone;

  final bool crewOk;
  final bool roadBlocked;
  final List<HelpKind> helpRequested;
  final IncidentStatus status;

  /// Where the reporter said it is. [checkpointId] is prefilled from their
  /// own assignment; [location] is best-effort GPS, because they may have
  /// moved from their post to reach the car, and a failed fix must never
  /// block a report going out.
  final String? checkpointId;
  final GeoPoint? location;

  final String? note;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  bool get isResolved => status == IncidentStatus.resolved;
}
