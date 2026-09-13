import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../rallies/data/rally_event.dart';
import 'event_visuals.dart';

/// One row of the activity log. Full-width tinted band with a hairline
/// rule, matching the design direction — deliberately not a rounded card
/// with a colored left border, which dev_notes.md §5 calls out as a look to
/// avoid. Color never carries meaning alone: every row pairs its tint with
/// an icon and an uppercase word, so it still reads correctly in grayscale
/// or to a color-blind marshal.
///
/// An organizer can tap a row to retract an entry they logged by mistake;
/// the row then renders struck through rather than disappearing. The action
/// is a visible trailing affordance rather than a long-press, because a
/// long-press advertises itself to nobody — an organizer would have to be
/// told the gesture exists — and it's awkward for anyone with limited
/// dexterity, which is not a great bet for a phone used in gloves.
class EventLogRow extends StatelessWidget {
  const EventLogRow({
    super.key,
    required this.event,
    this.nextInTime,
    this.onRetract,
  });

  final RallyEvent event;
  final RallyEvent? nextInTime;
  final VoidCallback? onRetract;

  @override
  Widget build(BuildContext context) {
    final retracted = event.isRetracted;
    final colors = retracted ? StatusColors.setup : colorsForEvent(event);
    final textTheme = Theme.of(context).textTheme;
    final strike = retracted ? TextDecoration.lineThrough : null;
    final loud = rendersLoud(event);
    final background = loud ? colors.base : colors.tint;
    final foreground = loud ? AppColors.surface : colors.text;

    final canRetract = !retracted && onRetract != null;

    return InkWell(
      onTap: canRetract ? onRetract : null,
      child: Container(
        color: background,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 2),
        child: Row(
          children: [
            Icon(iconForEvent(event), size: 20, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        event.label,
                        style: textTheme.labelSmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          decoration: strike,
                        ),
                      ),
                      if (retracted) ...[
                        const SizedBox(width: 8),
                        Text(
                          'RETRACTED',
                          style: textTheme.labelSmall?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    // A withdrawn entry shows what it said, not a computed
                    // range — the duration of something that didn't happen
                    // isn't meaningful.
                    retracted
                        ? event.title
                        : eventBodyText(event, nextInTime: nextInTime),
                    style: textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      decoration: strike,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              DateFormat.Hm().format(event.occurredAt),
              style: textTheme.bodySmall?.copyWith(
                color: foreground,
                decoration: strike,
              ),
            ),
            if (canRetract)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.more_vert,
                  size: 18,
                  color: foreground.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
