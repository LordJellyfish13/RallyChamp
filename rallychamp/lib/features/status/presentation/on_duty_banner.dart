import 'package:flutter/material.dart';

import '../../../core/map/directions_link.dart';
import '../../../core/theme/app_colors.dart';
import '../../applications/data/staff_application_summary.dart';
import '../../applications/data/staff_role.dart';
import '../../applications/presentation/people_page.dart';
import '../../incidents/presentation/report_incident_page.dart';
import '../../rallies/data/checkpoint.dart';

/// Shown at the top of the Status page when the signed-in user is accepted
/// staff on the active rally and it's genuinely live — the ops-mode surface
/// for accepted staff (dev_notes.md §5 "People screen + on-duty assignment
/// banner"), deliberately a card on an existing page rather than a bottom-
/// nav switch: it fits the app's existing per-page pattern instead of
/// making `MainScreen` reactive to auth/rally state for the first time.
class OnDutyBanner extends StatelessWidget {
  const OnDutyBanner({
    super.key,
    required this.rallyId,
    required this.application,
    required this.checkpoint,
  });

  final String rallyId;
  final StaffApplicationSummary application;
  final Checkpoint? checkpoint;

  @override
  Widget build(BuildContext context) {
    final roleLabel = application.role == StaffRole.judge ? 'Judge' : 'Marshal';
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      color: AppColors.successTint,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.badge_outlined, color: AppColors.success),
                const SizedBox(width: 8),
                Text(
                  "You're on duty — $roleLabel",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              checkpoint != null
                  ? 'Checkpoint ${checkpoint!.code} · ${checkpoint!.kind.label}'
                  : 'No checkpoint assigned yet',
            ),
            const SizedBox(height: 12),
            // The loudest thing on the card, and deliberately so: this is
            // the one action where seconds matter, and the person tapping
            // it is not reading carefully.
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.statusStopped,
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReportIncidentPage(rallyId: rallyId),
                  ),
                ),
                icon: const Icon(Icons.warning_amber_rounded),
                label: const Text('Report incident'),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (checkpoint?.location != null)
                  OutlinedButton.icon(
                    onPressed: () => openDirections(checkpoint!.location!),
                    icon: const Icon(Icons.directions),
                    label: const Text('Get directions'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PeoplePage(rallyId: rallyId),
                    ),
                  ),
                  icon: const Icon(Icons.groups_outlined),
                  label: const Text('Who else is working'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
