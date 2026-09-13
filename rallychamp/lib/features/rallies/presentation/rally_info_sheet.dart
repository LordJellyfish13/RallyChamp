import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../data/rally_summary.dart';

/// What the caller has to act on after the sheet closes. Calling the
/// organizer is handled inside the sheet (it leaves the app entirely);
/// editing and unfollowing both change what the caller is showing, so
/// they come back out.
enum RallyInfoAction { edit, stopFollowing }

/// The "what is this rally" sheet: dates, location, description, and how
/// to reach the organizer. Reachable from the Status page, which otherwise
/// only ever answers "what is happening right now" — the rally's own
/// details had no home in the app at all before this, despite the create
/// form having collected them since day one.
Future<RallyInfoAction?> showRallyInfoSheet(
  BuildContext context, {
  required RallySummary rally,
  required bool isAdmin,
}) {
  return showModalBottomSheet<RallyInfoAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _RallyInfoSheet(rally: rally, isAdmin: isAdmin),
  );
}

class _RallyInfoSheet extends StatelessWidget {
  const _RallyInfoSheet({required this.rally, required this.isAdmin});

  final RallySummary rally;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dates = rallyDateRange(rally.startDate, rally.endDate);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(rally.name, style: textTheme.headlineSmall),
            const SizedBox(height: 16),
            if (dates.isNotEmpty)
              _InfoRow(icon: Icons.event_outlined, text: dates),
            if (rally.locationName.isNotEmpty)
              _InfoRow(
                icon: Icons.place_outlined,
                text: rally.locationName,
              ),
            // No status row on purpose: the hero card behind this sheet
            // already states it, larger and live, and a second copy here
            // would be both redundant and a snapshot that can go stale
            // while the sheet is open.
            if (rally.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(rally.description, style: textTheme.bodyMedium),
            ],
            const SizedBox(height: 20),
            if (rally.organizerPhone != null)
              FilledButton.icon(
                onPressed: () => _call(context, rally.organizerPhone!),
                icon: const Icon(Icons.call),
                label: const Text('Call the organizer'),
              ),
            if (isAdmin) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(RallyInfoAction.edit),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit rally details'),
              ),
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () =>
                  Navigator.of(context).pop(RallyInfoAction.stopFollowing),
              icon: const Icon(Icons.bookmark_remove_outlined),
              label: const Text('Stop following'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _call(BuildContext context, String phone) async {
    final messenger = ScaffoldMessenger.of(context);
    // Spaces and dashes are how people actually write a number down, and
    // `tel:` won't take them.
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final launched = await launchUrl(Uri(scheme: 'tel', path: digits));
    if (!launched) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not start a call to $phone')),
      );
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.inkSoft),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
