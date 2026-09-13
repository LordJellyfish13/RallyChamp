import 'package:flutter_test/flutter_test.dart';
import 'package:rallychamp/features/rallies/data/rally_summary.dart';

void main() {
  group('rallyDateRange', () {
    test('a one-day rally reads as a single date', () {
      expect(
        rallyDateRange(DateTime(2026, 9, 13), DateTime(2026, 9, 13)),
        '13 Sep 2026',
      );
    });

    test('a weekend collapses the repeated month and year', () {
      expect(
        rallyDateRange(DateTime(2026, 9, 12), DateTime(2026, 9, 13)),
        '12–13 Sep 2026',
      );
    });

    test('spanning a month keeps both months but one year', () {
      expect(
        rallyDateRange(DateTime(2026, 9, 30), DateTime(2026, 10, 2)),
        '30 Sep – 2 Oct 2026',
      );
    });

    test('spanning new year spells out both halves', () {
      expect(
        rallyDateRange(DateTime(2026, 12, 30), DateTime(2027, 1, 2)),
        '30 Dec 2026 – 2 Jan 2027',
      );
    });

    test('a missing end date falls back to just the start', () {
      expect(rallyDateRange(DateTime(2026, 9, 13), null), '13 Sep 2026');
    });

    test('no dates at all produce nothing to show, not a placeholder', () {
      // Callers check for empty to decide whether to render the row at
      // all — a rally created before these fields were read would
      // otherwise show a bogus date.
      expect(rallyDateRange(null, null), '');
      expect(rallyDateRange(null, DateTime(2026, 9, 13)), '');
    });

    test('ignores a time-of-day difference within the same day', () {
      expect(
        rallyDateRange(
          DateTime(2026, 9, 13, 8),
          DateTime(2026, 9, 13, 19, 30),
        ),
        '13 Sep 2026',
      );
    });
  });
}
