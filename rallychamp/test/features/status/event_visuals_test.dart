import 'package:flutter_test/flutter_test.dart';
import 'package:rallychamp/core/theme/app_colors.dart';
import 'package:rallychamp/features/rallies/data/rally_event.dart';
import 'package:rallychamp/features/status/presentation/event_visuals.dart';

RallyEvent _event({
  required String status,
  required DateTime at,
  DateTime? estimatedEndAt,
}) {
  final (label, title, severity) = statusEventPresentation(status);
  return RallyEvent(
    id: status,
    type: RallyEventType.statusChange,
    severity: severity,
    label: label,
    title: title,
    status: status,
    occurredAt: at,
    estimatedEndAt: estimatedEndAt,
  );
}

RallyEvent _incident({
  required RallyEventType type,
  required RallyEventSeverity severity,
}) {
  return RallyEvent(
    id: 'i1',
    type: type,
    severity: severity,
    label: 'ALERT',
    title: 'Crash near R10',
    occurredAt: DateTime(2026, 9, 12, 11, 0),
  );
}

void main() {
  group('eventBodyText', () {
    final start = DateTime(2026, 9, 12, 11, 25);

    test('a non-pause event just reads as its title', () {
      expect(
        eventBodyText(_event(status: 'running', at: start)),
        'Rally active',
      );
    });

    test('an ongoing pause with no estimate shows when it started', () {
      expect(
        eventBodyText(_event(status: 'paused', at: start)),
        'since 11:25',
      );
    });

    test('an ongoing pause with an estimate shows the expected range', () {
      final event = _event(
        status: 'paused',
        at: start,
        estimatedEndAt: DateTime(2026, 9, 12, 12, 10),
      );
      expect(eventBodyText(event), 'est. 11:25 – 12:10');
    });

    test('a finished pause takes its end from the next event', () {
      final resumed = _event(
        status: 'running',
        at: DateTime(2026, 9, 12, 12, 10),
      );
      expect(
        eventBodyText(_event(status: 'paused', at: start), nextInTime: resumed),
        '11:25 – 12:10 · 45 min',
      );
    });

    test('a finished lunch break reports hours as well as minutes', () {
      final resumed = _event(
        status: 'running',
        at: DateTime(2026, 9, 12, 13, 30),
      );
      expect(
        eventBodyText(
          _event(status: 'lunch break', at: start),
          nextInTime: resumed,
        ),
        '11:25 – 13:30 · 2 h 5 min',
      );
    });
  });

  group('colorsForEvent', () {
    test('status events use the six-color rally palette', () {
      final at = DateTime(2026, 9, 12, 11, 0);
      expect(colorsForEvent(_event(status: 'running', at: at)),
          StatusColors.running);
      expect(colorsForEvent(_event(status: 'paused', at: at)),
          StatusColors.paused);
      expect(colorsForEvent(_event(status: 'lunch break', at: at)),
          StatusColors.lunch);
    });

    test('a stopped rally is the calm finished blue, never the danger red', () {
      final stopped = _event(
        status: 'stopped',
        at: DateTime(2026, 9, 12, 17, 0),
      );
      expect(colorsForEvent(stopped), StatusColors.finished);
      expect(colorsForEvent(stopped), isNot(StatusColors.stopped));
    });

    test('events with no status fall back to their severity', () {
      expect(
        colorsForEvent(
          _incident(
            type: RallyEventType.incidentOpened,
            severity: RallyEventSeverity.danger,
          ),
        ),
        StatusColors.stopped,
      );
      expect(
        colorsForEvent(
          _incident(
            type: RallyEventType.incidentResolved,
            severity: RallyEventSeverity.good,
          ),
        ),
        StatusColors.running,
      );
    });
  });

  group('retracted entries', () {
    RallyEvent retracted(RallyEvent event) => RallyEvent(
      id: event.id,
      type: event.type,
      severity: event.severity,
      label: event.label,
      title: event.title,
      status: event.status,
      occurredAt: event.occurredAt,
      retractedAt: DateTime(2026, 9, 12, 12, 0),
      retractedBy: 'admin-1',
    );

    test('the hero skips a retracted entry for the one below it', () {
      final events = [
        retracted(_event(status: 'stopped', at: DateTime(2026, 9, 12, 11, 25))),
        _event(status: 'running', at: DateTime(2026, 9, 12, 9, 5)),
      ];
      expect(currentEvent(events)?.status, 'running');
    });

    test('the hero falls back to null when everything is retracted', () {
      final events = [
        retracted(_event(status: 'stopped', at: DateTime(2026, 9, 12, 11, 25))),
      ];
      expect(currentEvent(events), isNull);
    });

    test('a retracted entry does not close a pause', () {
      // 11:25 paused, 11:30 finish (mis-tap, retracted), 11:35 resumed —
      // the pause ran until 11:35, not 11:30.
      final events = [
        _event(status: 'running', at: DateTime(2026, 9, 12, 11, 35)),
        retracted(_event(status: 'stopped', at: DateTime(2026, 9, 12, 11, 30))),
        _event(status: 'paused', at: DateTime(2026, 9, 12, 11, 25)),
      ];
      final closing = closingEventFor(events, 2);
      expect(closing?.occurredAt, DateTime(2026, 9, 12, 11, 35));
      expect(
        eventBodyText(events[2], nextInTime: closing),
        '11:25 – 11:35 · 10 min',
      );
    });

    test('an entry with nothing newer left has no closing event', () {
      final events = [
        _event(status: 'paused', at: DateTime(2026, 9, 12, 11, 25)),
      ];
      expect(closingEventFor(events, 0), isNull);
    });
  });

  group('rendersLoud', () {
    test('only danger events get the loud treatment', () {
      final at = DateTime(2026, 9, 13, 11, 0);
      expect(rendersLoud(_event(status: 'running', at: at)), isFalse);
      expect(rendersLoud(_event(status: 'paused', at: at)), isFalse);
      expect(
        rendersLoud(
          _incident(
            type: RallyEventType.incidentOpened,
            severity: RallyEventSeverity.danger,
          ),
        ),
        isTrue,
      );
    });

    test('a retracted alert stops shouting', () {
      final alert = _incident(
        type: RallyEventType.incidentOpened,
        severity: RallyEventSeverity.danger,
      );
      final withdrawn = RallyEvent(
        id: alert.id,
        type: alert.type,
        severity: alert.severity,
        label: alert.label,
        title: alert.title,
        occurredAt: alert.occurredAt,
        retractedAt: DateTime(2026, 9, 13, 11, 5),
        retractedBy: 'admin-1',
      );
      expect(rendersLoud(withdrawn), isFalse);
    });
  });

  group('incident event data', () {
    test('a public alert row names the checkpoint but not the detail', () {
      final data = incidentOpenedEventData(
        incidentId: 'i1',
        roadBlocked: false,
        checkpointCode: 'R1',
      );
      expect(data['label'], 'ALERT');
      expect(data['severity'], 'danger');
      expect(data['title'], 'Incident reported near R1');
      expect(data['incidentId'], 'i1');
    });

    test('a blocked road says the stage is held', () {
      final data = incidentOpenedEventData(
        incidentId: 'i1',
        roadBlocked: true,
        checkpointCode: 'R1',
      );
      expect(data['title'], 'Stage held — incident near R1');
    });

    test('resolving posts a good-severity all-clear', () {
      final data = incidentResolvedEventData(
        incidentId: 'i1',
        checkpointCode: 'R1',
      );
      expect(data['label'], 'CLEAR');
      expect(data['severity'], 'good');
      expect(data['title'], 'Incident near R1 resolved');
    });
  });

  group('statusChangeEventData', () {
    test('freezes the label, title and severity onto the document', () {
      final data = statusChangeEventData('running');
      expect(data['type'], 'status_change');
      expect(data['label'], 'GO');
      expect(data['title'], 'Rally active');
      expect(data['severity'], 'good');
      expect(data['status'], 'running');
    });

    test('a stopped rally is neutral, not danger', () {
      expect(statusChangeEventData('stopped')['severity'], 'neutral');
    });
  });
}
