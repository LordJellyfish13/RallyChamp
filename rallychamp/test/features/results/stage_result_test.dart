import 'package:flutter_test/flutter_test.dart';
import 'package:rallychamp/features/entries/data/entry.dart';
import 'package:rallychamp/features/results/data/stage_result.dart';

Entry _entry(String id, String carNumber) => Entry(
  id: id,
  uid: 'u-$id',
  teamName: 'Team',
  driverName: 'Driver $id',
  coDriverName: 'Co $id',
  carNumber: carNumber,
  carClass: 'N4',
  status: EntryStatus.accepted,
  appliedAt: DateTime(2026, 9, 13),
);

StageResult _result(
  String entryId,
  String stageId, {
  int? timeMs,
  ResultStatus status = ResultStatus.finished,
}) => StageResult(
  id: '${stageId}_$entryId',
  stageId: stageId,
  entryId: entryId,
  carNumber: '0',
  status: status,
  timeMs: timeMs,
);

void main() {
  group('parseStageTime', () {
    test('reads the usual minutes:seconds.hundredths', () {
      expect(parseStageTime('4:32.71'), 272710);
    });

    test('reads bare seconds', () {
      expect(parseStageTime('32.71'), 32710);
    });

    test('reads hours for a long road section', () {
      expect(parseStageTime('1:02:33.4'), 3753400);
    });

    test('accepts a comma decimal, as a European keyboard produces', () {
      expect(parseStageTime('32,71'), 32710);
    });

    test('rejects nonsense rather than guessing a time', () {
      expect(parseStageTime('abc'), isNull);
      expect(parseStageTime(''), isNull);
      expect(parseStageTime('1:2:3:4'), isNull);
      expect(parseStageTime('-5'), isNull);
    });
  });

  group('formatStageTime', () {
    test('round-trips a parsed time', () {
      expect(formatStageTime(parseStageTime('4:32.71')!), '4:32.71');
    });

    test('pads seconds and hundredths', () {
      expect(formatStageTime(62050), '1:02.05');
    });

    test('only shows hours when there are any', () {
      expect(formatStageTime(3753400), '1:02:33.40');
      expect(formatStageTime(32710), '0:32.71');
    });
  });

  group('computeStandings', () {
    final alice = _entry('a', '1');
    final bob = _entry('b', '2');
    final cara = _entry('c', '3');

    test('ranks finishers by total time', () {
      final rows = computeStandings(
        [alice, bob],
        [
          _result('a', 's1', timeMs: 200000),
          _result('b', 's1', timeMs: 190000),
        ],
      );
      expect(rows.map((r) => r.entry.id), ['b', 'a']);
      expect(rows.first.totalMs, 190000);
    });

    test('sums across stages', () {
      final rows = computeStandings(
        [alice],
        [
          _result('a', 's1', timeMs: 100000),
          _result('a', 's2', timeMs: 50000),
        ],
      );
      expect(rows.single.totalMs, 150000);
      expect(rows.single.stagesCompleted, 2);
    });

    test('more stages completed outranks a quicker partial time', () {
      // Mid-rally this is the whole point: someone who has done two stages
      // is ahead of someone who has only done one, whatever the clock says.
      final rows = computeStandings(
        [alice, bob],
        [
          _result('a', 's1', timeMs: 100000),
          _result('a', 's2', timeMs: 100000),
          _result('b', 's1', timeMs: 50000),
        ],
      );
      expect(rows.map((r) => r.entry.id), ['a', 'b']);
    });

    test('a crew that stopped drops below everyone still running', () {
      final rows = computeStandings(
        [alice, bob],
        [
          _result('a', 's1', timeMs: 100000),
          _result('a', 's2', status: ResultStatus.dnf),
          _result('b', 's1', timeMs: 900000),
        ],
      );
      expect(rows.map((r) => r.entry.id), ['b', 'a']);
      expect(rows.last.status, ResultStatus.dnf);
      expect(rows.last.isRunning, isFalse);
    });

    test('a DNF keeps the times it did set', () {
      final rows = computeStandings(
        [alice],
        [
          _result('a', 's1', timeMs: 100000),
          _result('a', 's2', status: ResultStatus.dnf),
        ],
      );
      expect(rows.single.stagesCompleted, 1);
      expect(rows.single.totalMs, 100000);
    });

    test('entries with no result at all are left out entirely', () {
      final rows = computeStandings(
        [alice, cara],
        [_result('a', 's1', timeMs: 100000)],
      );
      expect(rows.map((r) => r.entry.id), ['a']);
    });

    test('identical times fall back to car number', () {
      final rows = computeStandings(
        [bob, alice],
        [
          _result('a', 's1', timeMs: 100000),
          _result('b', 's1', timeMs: 100000),
        ],
      );
      expect(rows.map((r) => r.entry.carNumber), ['1', '2']);
    });
  });
}
