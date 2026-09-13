import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rallychamp/core/theme/app_colors.dart';
import 'package:rallychamp/features/rallies/data/rally_event.dart';
import 'package:rallychamp/features/rallies/data/stage.dart';
import 'package:rallychamp/features/status/presentation/event_visuals.dart';

RallyEvent _stageEvent(String status) {
  final data = stageStatusEventData(
    stageId: 's1',
    stageName: 'SS2',
    status: status,
  );
  return RallyEvent(
    id: 'e1',
    type: RallyEventType.stageStatusChange,
    severity: switch (data['severity']) {
      'good' => RallyEventSeverity.good,
      'warning' => RallyEventSeverity.warning,
      'danger' => RallyEventSeverity.danger,
      _ => RallyEventSeverity.neutral,
    },
    label: data['label'] as String,
    title: data['title'] as String,
    status: data['status'] as String?,
    stageId: data['stageId'] as String?,
    occurredAt: DateTime(2026, 9, 13, 10),
  );
}

void main() {
  group('stageStatusFromFirestore', () {
    test('reads the four real values', () {
      expect(stageStatusFromFirestore('scheduled'), StageStatus.scheduled);
      expect(stageStatusFromFirestore('running'), StageStatus.running);
      expect(stageStatusFromFirestore('finished'), StageStatus.finished);
      expect(stageStatusFromFirestore('cancelled'), StageStatus.cancelled);
    });

    test('the legacy "setup" seed reads as scheduled, needing no migration', () {
      // createRally has written 'setup' onto every stage since before this
      // enum existed.
      expect(stageStatusFromFirestore('setup'), StageStatus.scheduled);
    });

    test('an unknown or missing value falls back to scheduled', () {
      expect(stageStatusFromFirestore(null), StageStatus.scheduled);
      expect(stageStatusFromFirestore('who knows'), StageStatus.scheduled);
    });
  });

  group('Stage.distanceLabel', () {
    Stage stageWith(double? km) => Stage(
      id: 's1',
      name: 'SS1',
      order: 0,
      route: const [],
      distanceKm: km,
    );

    test('publishes one decimal, as stage lengths are quoted', () {
      expect(stageWith(12.4).distanceLabel, '12.4 km');
      expect(stageWith(8).distanceLabel, '8.0 km');
    });

    test('rounds to that decimal rather than showing float noise', () {
      expect(stageWith(12.449).distanceLabel, '12.4 km');
    });

    test('is null when unset, so callers omit the row entirely', () {
      // These fields were seeded as null by createRally long before
      // anything read them, so "no length yet" is the common case.
      expect(stageWith(null).distanceLabel, isNull);
    });
  });

  group('routeLengthKm', () {
    test('null for a route too short to measure', () {
      expect(routeLengthKm(const []), isNull);
      expect(routeLengthKm([const LatLng(45.0, 14.0)]), isNull);
    });

    test('measures a two-point route as the distance between them', () {
      // Roughly 0.01 degrees of latitude is ~1.11 km anywhere on Earth.
      final km = routeLengthKm(const [
        LatLng(45.0, 14.0),
        LatLng(45.01, 14.0),
      ]);
      expect(km, closeTo(1.11, 0.05));
    });

    test('sums each leg rather than the direct start-to-finish distance', () {
      // Confirms it's walking the polyline, not taking a shortcut across
      // it — a route with a detour must measure longer than the direct
      // line between its endpoints.
      final direct = routeLengthKm(const [
        LatLng(45.0, 14.0),
        LatLng(45.02, 14.0),
      ])!;
      final viaDetour = routeLengthKm(const [
        LatLng(45.0, 14.0),
        LatLng(45.0, 14.02),
        LatLng(45.02, 14.0),
      ])!;
      expect(viaDetour, greaterThan(direct));
    });
  });

  group('Stage distance: measured route vs organizer override', () {
    // ~1.11 km, per the routeLengthKm tests above.
    const route = [LatLng(45.0, 14.0), LatLng(45.01, 14.0)];

    test('falls back to the measured route length when no override is set', () {
      const stage = Stage(id: 's', name: 'SS1', order: 0, route: route);
      expect(stage.hasDistanceOverride, isFalse);
      expect(stage.effectiveDistanceKm, closeTo(1.11, 0.05));
    });

    test('an explicit override wins over the measured length', () {
      // The rare case: a published figure differs from what got drawn.
      const stage = Stage(
        id: 's',
        name: 'SS1',
        order: 0,
        route: route,
        distanceKm: 12.4,
      );
      expect(stage.hasDistanceOverride, isTrue);
      expect(stage.effectiveDistanceKm, 12.4);
    });

    test('a measured label is marked approximate; an override is not', () {
      // The tilde is the only signal in the UI that a number came from a
      // GPS track rather than a published figure — worth pinning down.
      const measured = Stage(id: 's', name: 'SS1', order: 0, route: route);
      const overridden = Stage(
        id: 's',
        name: 'SS1',
        order: 0,
        route: route,
        distanceKm: 12.4,
      );
      expect(measured.distanceLabel, startsWith('~'));
      expect(overridden.distanceLabel, isNot(startsWith('~')));
    });

    test('no route and no override means nothing to show', () {
      const stage = Stage(id: 's', name: 'SS1', order: 0, route: []);
      expect(stage.effectiveDistanceKm, isNull);
      expect(stage.distanceLabel, isNull);
    });
  });

  group('StageStatus.isOpen', () {
    test('a stage cars can still run is open', () {
      expect(StageStatus.scheduled.isOpen, isTrue);
      expect(StageStatus.running.isOpen, isTrue);
    });

    test('a finished or cancelled stage is not', () {
      expect(StageStatus.finished.isOpen, isFalse);
      expect(StageStatus.cancelled.isOpen, isFalse);
    });
  });

  group('stageStatusEventData', () {
    test('freezes the stage name into the title', () {
      // So renaming the stage later never rewrites what the log said.
      final data = stageStatusEventData(
        stageId: 's1',
        stageName: 'SS2 Kanfanar',
        status: 'running',
      );
      expect(data['title'], 'SS2 Kanfanar running');
      expect(data['label'], 'STAGE ON');
      expect(data['type'], 'stage_status_change');
      expect(data['stageId'], 's1');
    });

    test('a cancelled stage is a warning, never danger', () {
      // Red stays reserved for incidents.
      expect(
        stageStatusEventData(stageId: 's', stageName: 'SS1', status: 'cancelled')['severity'],
        'warning',
      );
    });

    test('finishing a stage is neutral, not celebratory', () {
      expect(
        stageStatusEventData(stageId: 's', stageName: 'SS1', status: 'finished')['severity'],
        'neutral',
      );
    });
  });

  group('event visuals for stage rows', () {
    test('a cancelled stage uses its severity, not the rally palette', () {
      // The regression this guards: stage statuses share the word
      // "running" with rally statuses, so keying the rally palette off
      // `status` alone tinted 'cancelled' grey — there is no such rally
      // status — while its severity said warning.
      final cancelled = colorsForEvent(_stageEvent('cancelled'));
      expect(cancelled, StatusColors.paused);
    });

    test('a finished stage does not borrow the rally finish colour', () {
      expect(colorsForEvent(_stageEvent('finished')), StatusColors.setup);
    });

    test('stage rows never render loud — that belongs to incidents', () {
      for (final status in ['running', 'finished', 'cancelled']) {
        expect(rendersLoud(_stageEvent(status)), isFalse, reason: status);
      }
    });

    test('stage rows get road icons, not the rally flags', () {
      expect(iconForEvent(_stageEvent('running')), isNot(Icons.play_arrow_rounded));
    });
  });
}
