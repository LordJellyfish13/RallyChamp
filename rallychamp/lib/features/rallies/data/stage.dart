import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// Where a single stage is in its own lifecycle, which is not the same
/// question as the rally's status: mid-rally SS1 can be finished while SS2
/// is still scheduled and SS3 has been cancelled for weather. The rally
/// status answers "is the event running at all"; this answers "can I still
/// see cars on this stage".
///
/// Deliberately four values. There's no per-stage "paused" because a stage
/// held mid-run is an incident, and that already has its own path through
/// `incidents/{id}` and the red activity-log row.
enum StageStatus { scheduled, running, finished, cancelled }

/// `createRally` seeds every stage with `'setup'`, which predates this
/// enum — it reads as [StageStatus.scheduled], same as anything
/// unrecognised, so old rallies need no migration.
StageStatus stageStatusFromFirestore(String? value) => switch (value) {
  'running' => StageStatus.running,
  'finished' => StageStatus.finished,
  'cancelled' => StageStatus.cancelled,
  _ => StageStatus.scheduled,
};

extension StageStatusX on StageStatus {
  String get firestoreValue => switch (this) {
    StageStatus.scheduled => 'scheduled',
    StageStatus.running => 'running',
    StageStatus.finished => 'finished',
    StageStatus.cancelled => 'cancelled',
  };

  String get label => switch (this) {
    StageStatus.scheduled => 'Scheduled',
    StageStatus.running => 'Running',
    StageStatus.finished => 'Finished',
    StageStatus.cancelled => 'Cancelled',
  };

  /// True while cars may still run it — what the Results tab uses to decide
  /// whether a stage's times are provisional or final.
  bool get isOpen => this == StageStatus.scheduled || this == StageStatus.running;
}

class Stage {
  const Stage({
    required this.id,
    required this.name,
    required this.order,
    required this.route,
    this.status = StageStatus.scheduled,
    this.distanceKm,
    this.scheduledStart,
  });

  factory Stage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawRoute = data['route'] as List<dynamic>? ?? const [];
    return Stage(
      id: doc.id,
      name: data['name'] as String? ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
      status: stageStatusFromFirestore(data['status'] as String?),
      distanceKm: (data['distanceKm'] as num?)?.toDouble(),
      scheduledStart: (data['scheduledStart'] as Timestamp?)?.toDate(),
      route: rawRoute
          .cast<Map<String, dynamic>>()
          .map(
            (point) => LatLng(
              (point['lat'] as num).toDouble(),
              (point['lng'] as num).toDouble(),
            ),
          )
          .toList(),
    );
  }

  final String id;
  final String name;
  final int order;
  final List<LatLng> route;
  final StageStatus status;

  /// When the stage is due to go off. Optional: `createRally` has always
  /// seeded it as null, and an organizer often draws the route long before
  /// the timetable is fixed.
  final DateTime? scheduledStart;

  /// An organizer-typed correction to the stage's length. Almost always
  /// null — the route the organizer already drew or GPS-recorded is a real
  /// measurement, so [effectiveDistanceKm] uses it automatically and
  /// nobody should have to type in a number the app can already compute.
  /// This exists only for the rare case where the published figure differs
  /// slightly from what was recorded (a road closure detour, a surveyed
  /// length that doesn't match the GPS track) and the organizer wants the
  /// exact published number to win.
  final double? distanceKm;

  bool get hasDistanceOverride => distanceKm != null;

  /// The route's length, measured by summing the distance between each
  /// consecutive pair of recorded points. Null before the route has at
  /// least two points to measure between.
  double? get measuredDistanceKm => routeLengthKm(route);

  /// What actually gets shown and used: the organizer's override if they
  /// set one, otherwise the measured route length.
  double? get effectiveDistanceKm => distanceKm ?? measuredDistanceKm;

  /// "12.4 km" for an explicit override, "~12.4 km" for a measured
  /// distance — the tilde is the one hint that this number came from a
  /// GPS track rather than a published figure, without needing separate
  /// UI to say so. One decimal, which is how stage lengths are published.
  String? get distanceLabel {
    final km = effectiveDistanceKm;
    if (km == null) return null;
    final formatted = '${km.toStringAsFixed(1)} km';
    return hasDistanceOverride ? formatted : '~$formatted';
  }
}

/// Sums the great-circle distance between each consecutive pair of points
/// in a route, in kilometers — the length of the road as recorded, not an
/// estimate. Null for fewer than two points, since there's nothing to
/// measure yet (a stage whose route hasn't been drawn).
double? routeLengthKm(List<LatLng> route) {
  if (route.length < 2) return null;
  const distance = Distance();
  var meters = 0.0;
  for (var i = 1; i < route.length; i++) {
    meters += distance(route[i - 1], route[i]);
  }
  return meters / 1000;
}
