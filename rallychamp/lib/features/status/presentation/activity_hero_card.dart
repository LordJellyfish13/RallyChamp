import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../rallies/data/rally_event.dart';
import '../../rallies/data/rally_summary.dart';
import 'event_visuals.dart';

/// The headline of the Status page: whatever happened most recently, big
/// enough to read across a service park. For an organizer it doubles as the
/// control — the quick actions sit right on it, so the most time-sensitive
/// action in the app is one tap from the thing telling you the current
/// state, rather than buried in a separate control further down.
class ActivityHeroCard extends StatelessWidget {
  const ActivityHeroCard({
    super.key,
    required this.event,
    required this.nextInTime,
    this.rallyStatus,
    this.actions,
  });

  final RallyEvent event;

  /// The rally's own status, used only when the headline is about
  /// something else — a stage or an incident. Those can be the newest
  /// event and so take the hero, which would otherwise leave the page
  /// unable to answer "is the rally even running?" at a glance. The
  /// quick actions on this card are rally-level, so the headline losing
  /// the rally's state entirely also left them without context.
  final String? rallyStatus;

  /// The event that happened *after* this one, if any — lets an ended pause
  /// show its real range. Always null for the hero, which by definition is
  /// the newest event, but kept explicit so the hero and the log rows share
  /// one text builder rather than drifting apart.
  final RallyEvent? nextInTime;

  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final colors = colorsForEvent(event);
    final loud = rendersLoud(event);
    final foreground = loud ? AppColors.surface : colors.text;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: loud ? colors.base : colors.tint,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: AppColors.surface,
              child: Icon(iconForEvent(event), size: 36, color: colors.base),
            ),
            const SizedBox(height: 16),
            Text(
              event.label,
              style: textTheme.labelMedium?.copyWith(
                color: foreground,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              event.title,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(color: foreground),
            ),
            const SizedBox(height: 6),
            Text(
              _subtitle(),
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: foreground),
            ),
            if (actions != null) ...[const SizedBox(height: 20), actions!],
          ],
        ),
      ),
    );
  }

  String _subtitle() {
    final time = DateFormat.Hm().format(event.occurredAt);
    if (event.isOngoingKind) {
      final body = eventBodyText(event, nextInTime: nextInTime);
      // "since 11:25" already carries the time; an estimate reads better
      // spelled out than as a bare range on the hero.
      final estimate = event.estimatedEndAt;
      if (nextInTime == null && estimate != null) {
        return 'Since $time · back by ~${DateFormat.Hm().format(estimate)}';
      }
      return body.substring(0, 1).toUpperCase() + body.substring(1);
    }
    return 'Since $time${_rallyStatusSuffix()}';
  }

  /// Empty when the headline *is* the rally's status — repeating it there
  /// would read as "Rally stopped … rally stopped".
  String _rallyStatusSuffix() {
    final status = rallyStatus;
    if (status == null || event.type == RallyEventType.statusChange) return '';
    return ' · ${rallyStatusLabel(status)}';
  }
}
