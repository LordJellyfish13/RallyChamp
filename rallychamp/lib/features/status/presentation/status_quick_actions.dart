import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/rally_status_cubit.dart';
import 'status_picker_sheet.dart';

/// The organizer's controls, sitting on the hero card. Only the moves that
/// actually happen mid-event get a button — everything else lives behind
/// "More". Going live, pausing and resuming are the actions someone takes
/// while standing in a field with a radio in the other hand, so they're one
/// tap; picking "setup" again is not, so it isn't.
class StatusQuickActions extends StatelessWidget {
  const StatusQuickActions({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final primary = switch (status) {
      'setup' || 'start' => const _Action('Go live', Icons.play_arrow_rounded, 'running'),
      'paused' || 'lunch break' => const _Action(
        'Resume',
        Icons.play_arrow_rounded,
        'running',
      ),
      'running' => const _Action('Pause', Icons.pause_rounded, 'paused'),
      _ => null,
    };
    final canFinish = status != 'stopped' && status != 'setup';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        if (primary != null)
          FilledButton.icon(
            onPressed: () => _apply(context, primary.status),
            icon: Icon(primary.icon),
            label: Text(primary.label),
          ),
        if (canFinish)
          OutlinedButton.icon(
            onPressed: () => _apply(context, 'stopped'),
            icon: const Icon(Icons.sports_score),
            label: const Text('Finish'),
          ),
        OutlinedButton.icon(
          onPressed: () => _openPicker(context),
          icon: const Icon(Icons.more_horiz),
          label: const Text('More'),
        ),
      ],
    );
  }

  Future<void> _apply(BuildContext context, String next) async {
    final choice = await resolvePauseChoice(context, next);
    if (choice == null || !context.mounted) return;
    await _write(context, choice);
  }

  Future<void> _openPicker(BuildContext context) async {
    final choice = await showStatusPickerSheet(context, current: status);
    if (choice == null || !context.mounted) return;
    await _write(context, choice);
  }

  Future<void> _write(BuildContext context, StatusChoice choice) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<RallyStatusCubit>().updateStatus(
        choice.status,
        estimatedEndAt: choice.estimatedEndAt,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update status: $e')),
      );
    }
  }
}

class _Action {
  const _Action(this.label, this.icon, this.status);

  final String label;
  final IconData icon;
  final String status;
}
