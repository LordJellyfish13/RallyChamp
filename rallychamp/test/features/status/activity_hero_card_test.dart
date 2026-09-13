import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallychamp/features/rallies/data/rally_event.dart';
import 'package:rallychamp/features/status/presentation/activity_hero_card.dart';

/// The project's first widget test. `ActivityHeroCard` is a good place to
/// start one: it's pure presentation with no Firebase anywhere near it, so
/// it pumps without any harness.
Future<void> _pump(
  WidgetTester tester,
  RallyEvent event, {
  String? rallyStatus,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ActivityHeroCard(
          event: event,
          nextInTime: null,
          rallyStatus: rallyStatus,
        ),
      ),
    ),
  );
}

RallyEvent _event({
  required RallyEventType type,
  required String label,
  required String title,
  String? status,
  RallyEventSeverity severity = RallyEventSeverity.neutral,
}) => RallyEvent(
  id: 'e1',
  type: type,
  severity: severity,
  label: label,
  title: title,
  status: status,
  occurredAt: DateTime(2026, 9, 13, 14, 5),
);

void main() {
  testWidgets('shows the event label and title', (tester) async {
    await _pump(
      tester,
      _event(
        type: RallyEventType.statusChange,
        label: 'GO',
        title: 'Rally active',
        status: 'running',
      ),
      rallyStatus: 'running',
    );

    expect(find.text('GO'), findsOneWidget);
    expect(find.text('Rally active'), findsOneWidget);
  });

  testWidgets('a rally status headline does not repeat itself', (tester) async {
    // Otherwise it would read "Rally stopped … Stopped".
    await _pump(
      tester,
      _event(
        type: RallyEventType.statusChange,
        label: 'FINISH',
        title: 'Rally stopped',
        status: 'stopped',
      ),
      rallyStatus: 'stopped',
    );

    expect(find.text('Since 14:05'), findsOneWidget);
  });

  testWidgets('a stage headline still says whether the rally is running', (
    tester,
  ) async {
    // The regression this guards: a stage event is the newest event, so it
    // takes the hero, and the page could no longer answer "is the rally
    // even on?" — while the quick actions sitting on this card are
    // rally-level.
    await _pump(
      tester,
      _event(
        type: RallyEventType.stageStatusChange,
        label: 'STAGE OFF',
        title: 'Stage 3 cancelled',
        status: 'cancelled',
        severity: RallyEventSeverity.warning,
      ),
      rallyStatus: 'stopped',
    );

    expect(find.text('Since 14:05 · Stopped'), findsOneWidget);
  });

  testWidgets('an incident headline does too', (tester) async {
    await _pump(
      tester,
      _event(
        type: RallyEventType.incidentOpened,
        label: 'ALERT',
        title: 'Incident reported near R2',
        severity: RallyEventSeverity.danger,
      ),
      rallyStatus: 'running',
    );

    expect(find.text('Since 14:05 · Running'), findsOneWidget);
  });

  testWidgets('omits the suffix when no rally status was passed', (
    tester,
  ) async {
    await _pump(
      tester,
      _event(
        type: RallyEventType.stageStatusChange,
        label: 'STAGE ON',
        title: 'Stage 2 running',
        status: 'running',
      ),
    );

    expect(find.text('Since 14:05'), findsOneWidget);
  });
}
