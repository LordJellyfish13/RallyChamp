import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/entry.dart';

/// One competitor, as a start-list row: car number in a prominent square,
/// then the crew. Shared by the public list and the organizer's review
/// screen so a competitor looks the same wherever they appear.
class EntryCard extends StatelessWidget {
  const EntryCard({
    super.key,
    required this.entry,
    this.trailing,
    this.footer,
    this.onTap,
  });

  final Entry entry;
  final Widget? trailing;
  final Widget? footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.charcoal,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      entry.carNumber,
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.surface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.driverName,
                          style: textTheme.titleMedium,
                        ),
                        // The crew is two people; the co-driver is not a
                        // footnote (dev_notes.md §5).
                        if (entry.coDriverName.isNotEmpty)
                          Text(
                            entry.coDriverName,
                            style: textTheme.bodyMedium,
                          ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (entry.teamName.isNotEmpty) entry.teamName,
                            if (entry.carClass.isNotEmpty) entry.carClass,
                          ].join(' · '),
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
              if (footer != null) ...[const SizedBox(height: 8), footer!],
            ],
          ),
        ),
      ),
    );
  }
}
