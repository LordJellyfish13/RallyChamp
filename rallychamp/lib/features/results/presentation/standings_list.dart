import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../entries/data/entry.dart';
import '../data/stage_result.dart';

/// The leaderboard — overall, or for a single stage.
///
/// Positions are computed here rather than stored (a deviation from §9's
/// schema, which lists a `position` field): a single corrected time would
/// otherwise mean rewriting every row below it, and a stale position is
/// worse than no position.
class StandingsList extends StatelessWidget {
  const StandingsList({
    super.key,
    required this.entries,
    required this.results,
    this.stageId,
  });

  final List<Entry> entries;
  final List<StageResult> results;

  /// Null for the overall standings; otherwise only this stage counts.
  final String? stageId;

  @override
  Widget build(BuildContext context) {
    final scoped = stageId == null
        ? results
        : results.where((result) => result.stageId == stageId).toList();
    final rows = computeStandings(entries, scoped);

    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No times recorded yet.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final leader = rows.first.isRunning ? rows.first.totalMs : null;

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          _StandingTile(
            row: rows[i],
            // Position only means something for crews still running; a DNF
            // isn't 7th, it's out.
            position: rows[i].isRunning ? i + 1 : null,
            gapMs: rows[i].isRunning && leader != null && i > 0
                ? rows[i].totalMs - leader
                : null,
          ),
      ],
    );
  }
}

class _StandingTile extends StatelessWidget {
  const _StandingTile({required this.row, this.position, this.gapMs});

  final StandingRow row;
  final int? position;
  final int? gapMs;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final out = !row.isRunning;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                position?.toString() ?? '—',
                style: textTheme.titleMedium?.copyWith(
                  color: out ? AppColors.inkSoft : AppColors.ink,
                ),
              ),
            ),
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: out ? AppColors.inkSoft : AppColors.charcoal,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                row.entry.carNumber,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.surface,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.entry.driverName, style: textTheme.titleSmall),
                  Text(
                    row.entry.coDriverName,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  out
                      ? row.status.label
                      : formatStageTime(row.totalMs),
                  style: textTheme.titleSmall?.copyWith(
                    color: out
                        ? AppColors.statusStoppedText
                        : AppColors.ink,
                  ),
                ),
                if (gapMs != null && gapMs! > 0)
                  Text(
                    '+${formatStageTime(gapMs!)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
