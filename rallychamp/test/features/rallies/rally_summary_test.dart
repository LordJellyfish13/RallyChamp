import 'package:flutter_test/flutter_test.dart';
import 'package:rallychamp/features/rallies/data/rally_summary.dart';

RallySummary _summary(String status) {
  return RallySummary(
    id: 'r1',
    name: 'Test Rally',
    description: '',
    visibility: 'published',
    status: status,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('RallySummary.displayStatus', () {
    test('setup and start map to upcoming', () {
      expect(_summary('setup').displayStatus, RallyDisplayStatus.upcoming);
      expect(_summary('start').displayStatus, RallyDisplayStatus.upcoming);
    });

    test('running, paused, and lunch break map to active', () {
      expect(_summary('running').displayStatus, RallyDisplayStatus.active);
      expect(_summary('paused').displayStatus, RallyDisplayStatus.active);
      expect(
        _summary('lunch break').displayStatus,
        RallyDisplayStatus.active,
      );
    });

    test('stopped maps to finished', () {
      expect(_summary('stopped').displayStatus, RallyDisplayStatus.finished);
    });
  });
}
