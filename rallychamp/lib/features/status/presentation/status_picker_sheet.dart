import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../rallies/data/rally_summary.dart';

/// What the organizer picked: a status, plus the optional "back by ~" time
/// that only pause-type statuses offer.
class StatusChoice {
  const StatusChoice(this.status, {this.estimatedEndAt});

  final String status;
  final DateTime? estimatedEndAt;
}

/// The full six-status picker, for the transitions the hero card's quick
/// actions don't cover (back to setup, lunch break, reopening a stopped
/// rally). Quick actions handle the common mid-event moves in one tap;
/// this is the escape hatch, not the main path.
Future<StatusChoice?> showStatusPickerSheet(
  BuildContext context, {
  required String current,
}) {
  return showModalBottomSheet<StatusChoice>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                'Set rally status',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            for (final status in rallyStatuses)
              ListTile(
                leading: Icon(
                  status == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: StatusColors.forRallyStatus(status).text,
                ),
                title: Text(rallyStatusLabel(status)),
                onTap: () async {
                  final choice = await _resolveChoice(sheetContext, status);
                  if (choice != null && sheetContext.mounted) {
                    Navigator.of(sheetContext).pop(choice);
                  }
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Pausing offers an optional expected-return time; every other status is
/// immediate. Deliberately two buttons rather than a form — an urgent pause
/// stays one extra tap, and the estimate never blocks it.
Future<StatusChoice?> resolvePauseChoice(
  BuildContext context,
  String status,
) => _resolveChoice(context, status);

Future<StatusChoice?> _resolveChoice(BuildContext context, String status) async {
  final isPause = status == 'paused' || status == 'lunch break';
  if (!isPause) return StatusChoice(status);

  final wantsEstimate = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                rallyStatusLabel(status),
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'An expected return time is shown to everyone following the '
                'rally. Skip it if you don\'t know yet.',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                child: const Text('Start now'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                icon: const Icon(Icons.schedule),
                label: const Text('Set expected return'),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (wantsEstimate == null) return null;
  if (!wantsEstimate) return StatusChoice(status);
  if (!context.mounted) return null;

  final now = DateTime.now();
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 30))),
    helpText: 'Expected return',
  );
  if (picked == null) return StatusChoice(status);

  var end = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
  // A return time earlier than now means they meant tomorrow — a rally
  // paused at 23:40 and back at 00:20 is a real (if unusual) case, and
  // silently rendering a negative range would be worse than assuming it.
  if (end.isBefore(now)) end = end.add(const Duration(days: 1));
  return StatusChoice(status, estimatedEndAt: end);
}

String formatEstimate(DateTime time) => DateFormat.Hm().format(time);
