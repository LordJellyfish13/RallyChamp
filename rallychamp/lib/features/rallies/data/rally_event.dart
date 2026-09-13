import 'package:cloud_firestore/cloud_firestore.dart';

/// What kind of thing happened. v1 only ever writes [statusChange]; the
/// incident types exist now so the feed, its rules, and its renderer are
/// already shaped for them — see dev_notes.md §5 "Rally activity log".
enum RallyEventType {
  statusChange,
  stageStatusChange,
  incidentOpened,
  incidentResolved,
  unknown,
}

/// Drives the row's color. Stored on the document rather than derived from
/// [RallyEventType] on the fly, unlike `RallySummary.displayStatus`: a log
/// is an immutable historical record, so a row has to keep rendering the
/// same way forever, and a client that predates a new event type still
/// needs to color it sensibly instead of falling back to blank.
enum RallyEventSeverity { good, warning, danger, neutral }

RallyEventType _typeFromFirestore(String? value) => switch (value) {
  'status_change' => RallyEventType.statusChange,
  'stage_status_change' => RallyEventType.stageStatusChange,
  'incident_opened' => RallyEventType.incidentOpened,
  'incident_resolved' => RallyEventType.incidentResolved,
  _ => RallyEventType.unknown,
};

RallyEventSeverity _severityFromFirestore(String? value) => switch (value) {
  'good' => RallyEventSeverity.good,
  'warning' => RallyEventSeverity.warning,
  'danger' => RallyEventSeverity.danger,
  _ => RallyEventSeverity.neutral,
};

extension RallyEventTypeX on RallyEventType {
  String get firestoreValue => switch (this) {
    RallyEventType.statusChange => 'status_change',
    RallyEventType.stageStatusChange => 'stage_status_change',
    RallyEventType.incidentOpened => 'incident_opened',
    RallyEventType.incidentResolved => 'incident_resolved',
    RallyEventType.unknown => 'unknown',
  };
}

extension RallyEventSeverityX on RallyEventSeverity {
  String get firestoreValue => switch (this) {
    RallyEventSeverity.good => 'good',
    RallyEventSeverity.warning => 'warning',
    RallyEventSeverity.danger => 'danger',
    RallyEventSeverity.neutral => 'neutral',
  };
}

/// How a status reads in the log: its short tag, its sentence, and its
/// severity. One definition, used both when writing an event and when
/// synthesizing the fallback one for a rally that has no log yet.
(String label, String title, RallyEventSeverity severity)
statusEventPresentation(String status) => switch (status) {
  'start' => ('START', 'Rally starting', RallyEventSeverity.good),
  'running' => ('GO', 'Rally active', RallyEventSeverity.good),
  'paused' => ('PAUSE STARTED', 'Rally paused', RallyEventSeverity.warning),
  'lunch break' => ('LUNCH BREAK', 'Lunch break', RallyEventSeverity.warning),
  // Neutral, not danger: a rally ending normally isn't an emergency, and
  // red has to stay reserved for incidents (see StatusColors).
  'stopped' => ('FINISH', 'Rally stopped', RallyEventSeverity.neutral),
  _ => ('SETUP', 'Rally in setup', RallyEventSeverity.neutral),
};

/// The public row announcing an incident. Deliberately vaguer than the
/// report behind it: spectators see that something happened and whether
/// the stage is held, not the crew's condition. A crash shouldn't be
/// broadcast in detail to a crowd — quite possibly including the crew's
/// family — before anyone has confirmed they're alright. The real detail
/// lives in `incidents/{id}`, which only staff can read, and rules are
/// per-document, which is why these are two documents (dev_notes.md §9).
Map<String, Object?> incidentOpenedEventData({
  required String incidentId,
  required bool roadBlocked,
  String? checkpointId,
  String? checkpointCode,
}) {
  final where = checkpointCode == null ? '' : ' near $checkpointCode';
  return {
    'type': RallyEventType.incidentOpened.firestoreValue,
    'severity': RallyEventSeverity.danger.firestoreValue,
    'label': 'ALERT',
    'title': roadBlocked
        ? 'Stage held — incident$where'
        : 'Incident reported$where',
    'detail': null,
    'status': null,
    'checkpointId': checkpointId,
    'incidentId': incidentId,
  };
}

Map<String, Object?> incidentResolvedEventData({
  required String incidentId,
  String? checkpointId,
  String? checkpointCode,
}) {
  final where = checkpointCode == null ? '' : ' near $checkpointCode';
  return {
    'type': RallyEventType.incidentResolved.firestoreValue,
    'severity': RallyEventSeverity.good.firestoreValue,
    'label': 'CLEAR',
    'title': 'Incident$where resolved',
    'detail': null,
    'status': null,
    'checkpointId': checkpointId,
    'incidentId': incidentId,
  };
}

/// A non-persisted event standing in for a rally's current status, so the
/// Status page's hero always has something real to render — rallies created
/// before the activity log existed have no events at all, and a brand-new
/// one's first event may not have synced yet.
RallyEvent syntheticStatusEvent(String status, DateTime occurredAt) {
  final (label, title, severity) = statusEventPresentation(status);
  return RallyEvent(
    id: '_current',
    type: RallyEventType.statusChange,
    severity: severity,
    label: label,
    title: title,
    status: status,
    occurredAt: occurredAt,
  );
}

/// The stored shape of a status-change event, minus the timestamps and
/// actor the repository adds. Lives next to the model rather than inline in
/// `RallyRepository` so the label/title/severity that get *frozen into the
/// log forever* are defined in exactly one place.
Map<String, Object?> statusChangeEventData(String status) {
  final (label, title, severity) = statusEventPresentation(status);
  return {
    'type': RallyEventType.statusChange.firestoreValue,
    'severity': severity.firestoreValue,
    'label': label,
    'title': title,
    'detail': null,
    'status': status,
    'checkpointId': null,
    'incidentId': null,
  };
}

/// How a stage's status reads in the log. Separate from
/// [statusEventPresentation] because the two answer different questions —
/// the rally one says whether the event is running at all, this one says
/// whether cars are on *this* road — and because a stage row has to name
/// which stage it's about.
///
/// Severity follows the same rule as the rally statuses: red belongs to
/// incidents, so a cancelled stage is a warning, not a danger.
(String label, String title, RallyEventSeverity severity)
stageStatusEventPresentation(String stageName, String status) =>
    switch (status) {
      'running' => ('STAGE ON', '$stageName running', RallyEventSeverity.good),
      'finished' => (
        'STAGE DONE',
        '$stageName finished',
        RallyEventSeverity.neutral,
      ),
      'cancelled' => (
        'STAGE OFF',
        '$stageName cancelled',
        RallyEventSeverity.warning,
      ),
      _ => (
        'STAGE SET',
        '$stageName back to scheduled',
        RallyEventSeverity.neutral,
      ),
    };

/// The stored shape of a stage-status event, minus the timestamps and
/// actor the repository adds. Like [statusChangeEventData], the wording is
/// frozen onto the document at write time so the row keeps reading the
/// same way forever — including the stage's name, which means renaming a
/// stage later doesn't rewrite history.
Map<String, Object?> stageStatusEventData({
  required String stageId,
  required String stageName,
  required String status,
}) {
  final (label, title, severity) = stageStatusEventPresentation(
    stageName,
    status,
  );
  return {
    'type': RallyEventType.stageStatusChange.firestoreValue,
    'severity': severity.firestoreValue,
    'label': label,
    'title': title,
    'detail': null,
    'status': status,
    'stageId': stageId,
    'checkpointId': null,
    'incidentId': null,
  };
}

/// One row in a rally's activity log (`rallies/{id}/events/{eventId}`).
///
/// Append-only: nothing ever edits an event after it's written. The pause
/// rows that show a finished range ("11:25 – 12:10") get their end from
/// the *next* event in the feed, computed at render time — no second write,
/// and no mutating history to make the UI work.
class RallyEvent {
  const RallyEvent({
    required this.id,
    required this.type,
    required this.severity,
    required this.label,
    required this.title,
    required this.occurredAt,
    this.detail,
    this.status,
    this.estimatedEndAt,
    this.stageId,
    this.checkpointId,
    this.incidentId,
    this.retractedAt,
    this.retractedBy,
  });

  factory RallyEvent.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return RallyEvent(
      id: doc.id,
      type: _typeFromFirestore(data['type'] as String?),
      severity: _severityFromFirestore(data['severity'] as String?),
      label: data['label'] as String? ?? '',
      title: data['title'] as String? ?? '',
      detail: data['detail'] as String?,
      status: data['status'] as String?,
      // Client-set, and what the feed sorts by — see
      // `RallyRepository.updateRallyStatus` for why it isn't the server
      // timestamp.
      occurredAt:
          (data['occurredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      estimatedEndAt: (data['estimatedEndAt'] as Timestamp?)?.toDate(),
      stageId: data['stageId'] as String?,
      checkpointId: data['checkpointId'] as String?,
      incidentId: data['incidentId'] as String?,
      retractedAt: (data['retractedAt'] as Timestamp?)?.toDate(),
      retractedBy: data['retractedBy'] as String?,
    );
  }

  final String id;
  final RallyEventType type;
  final RallyEventSeverity severity;

  /// The short uppercase tag on the row ("GO", "PAUSE STARTED", "ALERT").
  final String label;
  final String title;
  final String? detail;

  /// When it actually happened, set by the client that wrote it. The feed
  /// sorts by this rather than the server timestamp — see
  /// `RallyRepository.updateRallyStatus`.
  final DateTime occurredAt;

  /// The rally status this event moved to — `statusChange` events only.
  final String? status;

  /// Optional "back by ~" time an organizer set when pausing.
  final DateTime? estimatedEndAt;

  /// Which stage a `stageStatusChange` row is about. The stage's *name* is
  /// already baked into [title]; this is the id, so a future version can
  /// link the row through to the stage.
  final String? stageId;

  /// v2: which checkpoint an incident is at, and the `incidents/{id}` doc
  /// holding the detail that only staff can read.
  final String? checkpointId;
  final String? incidentId;

  /// Set when an organizer withdraws an entry they logged by mistake. The
  /// row stays in the feed, struck through — crossed out in the logbook,
  /// not torn out — and the original label/title/time are never touched
  /// (firestore.rules allows an update to reach these two keys and nothing
  /// else).
  final DateTime? retractedAt;
  final String? retractedBy;

  bool get isRetracted => retractedAt != null;

  /// True for the statuses where "it's still going on" is meaningful, so
  /// the row can show a live range instead of a single timestamp.
  bool get isOngoingKind =>
      status == 'paused' || status == 'lunch break';
}
