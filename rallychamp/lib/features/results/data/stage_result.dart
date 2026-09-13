import 'package:cloud_firestore/cloud_firestore.dart';

import '../../entries/data/entry.dart';

/// Not in the §9 schema, and it needs to be: a crew that crashes on stage
/// two has no time, and a results screen that can only express "a number"
/// can't say what happened to them.
enum ResultStatus { finished, dnf, dns, dsq }

extension ResultStatusX on ResultStatus {
  String get firestoreValue => switch (this) {
    ResultStatus.finished => 'finished',
    ResultStatus.dnf => 'dnf',
    ResultStatus.dns => 'dns',
    ResultStatus.dsq => 'dsq',
  };

  String get label => switch (this) {
    ResultStatus.finished => 'Finished',
    ResultStatus.dnf => 'DNF',
    ResultStatus.dns => 'DNS',
    ResultStatus.dsq => 'DSQ',
  };
}

ResultStatus _statusFromFirestore(String? value) => switch (value) {
  'dnf' => ResultStatus.dnf,
  'dns' => ResultStatus.dns,
  'dsq' => ResultStatus.dsq,
  _ => ResultStatus.finished,
};

/// Where a time came from. Carried from day one per dev_notes.md §7: some
/// rallies time by stopwatch, others by transponder, and retrofitting the
/// distinction later would mean touching every stored result.
enum ResultSource { manual, transponder }

extension ResultSourceX on ResultSource {
  String get firestoreValue =>
      this == ResultSource.transponder ? 'transponder' : 'manual';
}

/// One crew's run down one stage.
class StageResult {
  const StageResult({
    required this.id,
    required this.stageId,
    required this.entryId,
    required this.carNumber,
    required this.status,
    this.timeMs,
    this.source = ResultSource.manual,
  });

  factory StageResult.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return StageResult(
      id: doc.id,
      stageId: data['stageId'] as String? ?? '',
      entryId: data['entryId'] as String? ?? '',
      carNumber: data['carNumber'] as String? ?? '',
      status: _statusFromFirestore(data['status'] as String?),
      timeMs: (data['timeMs'] as num?)?.toInt(),
      source: data['source'] == 'transponder'
          ? ResultSource.transponder
          : ResultSource.manual,
    );
  }

  final String id;
  final String stageId;
  final String entryId;

  /// Denormalized so a results list renders without joining to entries —
  /// and so a result still reads correctly if an entry is later changed.
  final String carNumber;

  final ResultStatus status;

  /// Milliseconds, and null unless [status] is finished. An integer rather
  /// than a formatted string because these get sorted and summed; "4:32.71"
  /// does neither.
  final int? timeMs;

  final ResultSource source;

  bool get isFinished => status == ResultStatus.finished && timeMs != null;
}

/// "4:32.71" → 272710ms. Also accepts "32.71" and "1:02:33.4" so whoever
/// is typing can use whatever the stopwatch showed them, under pressure,
/// without thinking about the format.
int? parseStageTime(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;

  final parts = text.split(':');
  if (parts.length > 3) return null;

  var total = 0.0;
  for (final part in parts) {
    final value = double.tryParse(part.replaceAll(',', '.'));
    if (value == null || value < 0) return null;
    total = total * 60 + value;
  }
  return (total * 1000).round();
}

/// 272710ms → "4:32.71". Hours only appear when there are any, because a
/// leading "0:" on every stage time is noise.
String formatStageTime(int milliseconds) {
  final hundredths = (milliseconds / 10).round();
  final totalSeconds = hundredths ~/ 100;
  final fraction = hundredths % 100;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  final fractionText = fraction.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}'
        ':${seconds.toString().padLeft(2, '0')}.$fractionText';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}.$fractionText';
}

/// One crew's place in the standings.
class StandingRow {
  const StandingRow({
    required this.entry,
    required this.stagesCompleted,
    required this.totalMs,
    required this.status,
  });

  final Entry entry;
  final int stagesCompleted;
  final int totalMs;

  /// The worst thing that happened to them — a crew that finished stage
  /// one and crashed on stage two is DNF, not "1 stage completed".
  final ResultStatus status;

  bool get isRunning => status == ResultStatus.finished;
}

/// Standings, summed client-side (dev_notes.md §9 — fine at club scale;
/// a pre-aggregated document is the answer only at much larger spectator
/// counts).
///
/// Ranked by stages completed first, then total time. That ordering is
/// what makes it correct *mid-rally*: a crew who has finished two stages
/// is ahead of one who has finished one, regardless of elapsed time, and
/// the leaderboard stays sensible while results are still coming in.
/// Anyone who didn't finish drops to the bottom whatever their times were.
List<StandingRow> computeStandings(
  List<Entry> entries,
  List<StageResult> results,
) {
  final rows = <StandingRow>[];

  for (final entry in entries) {
    final own = results.where((result) => result.entryId == entry.id).toList();
    if (own.isEmpty) continue;

    final ended = own.firstWhere(
      (result) => result.status != ResultStatus.finished,
      orElse: () => own.first,
    );
    final status = ended.status != ResultStatus.finished
        ? ended.status
        : ResultStatus.finished;

    final finished = own.where((result) => result.isFinished);
    rows.add(
      StandingRow(
        entry: entry,
        stagesCompleted: finished.length,
        totalMs: finished.fold(0, (running, result) => running + result.timeMs!),
        status: status,
      ),
    );
  }

  rows.sort((a, b) {
    if (a.isRunning != b.isRunning) return a.isRunning ? -1 : 1;
    if (a.stagesCompleted != b.stagesCompleted) {
      return b.stagesCompleted.compareTo(a.stagesCompleted);
    }
    if (a.totalMs != b.totalMs) return a.totalMs.compareTo(b.totalMs);
    return compareCarNumbers(a.entry.carNumber, b.entry.carNumber);
  });

  return rows;
}
