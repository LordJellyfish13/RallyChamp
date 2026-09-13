import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// A rally's dates as one line, collapsing whatever the two dates have in
/// common: "13 Sep 2026" for a single day, "13–14 Sep 2026" within a
/// month, "30 Sep – 2 Oct 2026" within a year. Rallies are usually one or
/// two days, so repeating the month and year on both halves would be
/// noise. Returns an empty string when the dates are missing, which the
/// callers treat as "nothing to show" rather than printing a placeholder.
String rallyDateRange(DateTime? start, DateTime? end) {
  if (start == null) return '';
  final day = DateFormat('d');
  final dayMonth = DateFormat('d MMM');
  final full = DateFormat('d MMM yyyy');

  if (end == null || _sameDay(start, end)) return full.format(start);
  if (start.year != end.year) return '${full.format(start)} – ${full.format(end)}';
  if (start.month != end.month) {
    return '${dayMonth.format(start)} – ${full.format(end)}';
  }
  return '${day.format(start)}–${full.format(end)}';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Every value `rallies/{id}.status` can hold, in the order they'd
/// normally occur — not a constraint the app enforces (see
/// `RallyRepository.updateRallyStatus`), just the order the Status page's
/// organizer control lists them in.
const rallyStatuses = ['setup', 'start', 'running', 'paused', 'lunch break', 'stopped'];

/// Display label for a raw `status` value (as opposed to `displayStatus`
/// below, which buckets it down to three spectator-facing labels) — used
/// by the Status page's status display and organizer control, where the
/// real, specific status matters.
String rallyStatusLabel(String status) => switch (status) {
  'setup' => 'Setup',
  'start' => 'Start',
  'running' => 'Running',
  'paused' => 'Paused',
  'lunch break' => 'Lunch break',
  'stopped' => 'Stopped',
  _ => status,
};

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
    this.adminUids = const [],
    this.locationName = '',
    this.startDate,
    this.endDate,
    this.allowWalkupMarshals = true,
    this.organizerPhone,
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
      adminUids: (data['adminUids'] as List<dynamic>?)?.cast<String>() ?? const [],
      locationName: data['locationName'] as String? ?? '',
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      allowWalkupMarshals: data['allowWalkupMarshals'] as bool? ?? true,
      organizerPhone: data['organizerPhone'] as String?,
    );
  }

  final String id;
  final String name;
  final String description;
  final String visibility;
  final String status;
  final DateTime createdAt;

  /// Where the rally is held, as free text the organizer typed — these
  /// next four were written by `createRally` from the day it existed but
  /// read by nothing, so the organizer filled them in and they vanished.
  /// They're on the model now because the rally info sheet shows them and
  /// the edit screen writes them back.
  final String locationName;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool allowWalkupMarshals;

  /// Null until an organizer sets one. Optional on purpose: an organizer
  /// who doesn't want their phone in a public app simply leaves it blank,
  /// and the info sheet omits the call button rather than showing a dead
  /// one.
  final String? organizerPhone;

  /// Empty for a `RallySummary` resolved somewhere that never reads it
  /// (e.g. the switcher, before the Status page's own status-control gate
  /// needed it) — only populated where a caller actually needs to check
  /// admin access, like the Status page's status control.
  final List<String> adminUids;

  bool get isDraft => visibility == 'draft';

  RallyDisplayStatus get displayStatus => switch (status) {
    'running' || 'paused' || 'lunch break' => RallyDisplayStatus.active,
    'stopped' => RallyDisplayStatus.finished,
    _ => RallyDisplayStatus.upcoming, // setup, start, or anything unknown
  };
}
