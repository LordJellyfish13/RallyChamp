import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../rallies/data/rally_event.dart';

/// How one event renders: its three colors and its icon. Status events use
/// the full six-color rally palette (so a lunch break is visibly its own
/// thing, not just another amber "warning"); everything else falls back to
/// the four severity buckets, which is what makes an event type this client
/// has never heard of still render in a sensible color.
StatusColors colorsForEvent(RallyEvent event) {
  final status = event.status;
  // Only *rally* status events get the rally palette. Stage events carry a
  // `status` too, from a different vocabulary that happens to share the
  // word "running" — looking those up here would tint a cancelled stage
  // grey (no such rally status) while its severity says warning.
  if (status != null && event.type == RallyEventType.statusChange) {
    return StatusColors.forRallyStatus(status);
  }
  return switch (event.severity) {
    RallyEventSeverity.good => StatusColors.running,
    RallyEventSeverity.warning => StatusColors.paused,
    RallyEventSeverity.danger => StatusColors.stopped,
    RallyEventSeverity.neutral => StatusColors.setup,
  };
}

/// Whether an event gets the loud treatment: the saturated colour with
/// white text, instead of the light tint every routine row uses.
///
/// Only danger events qualify, and that restraint is the point — if GO and
/// PAUSE shouted too, a crash row would look like more of the same. A
/// retracted alert drops back to quiet: it's been withdrawn, so it has no
/// business still grabbing the eye.
bool rendersLoud(RallyEvent event) =>
    event.severity == RallyEventSeverity.danger && !event.isRetracted;

IconData iconForEvent(RallyEvent event) {
  if (event.type == RallyEventType.incidentOpened) {
    return Icons.warning_amber_rounded;
  }
  if (event.type == RallyEventType.incidentResolved) {
    return Icons.check_circle_outline;
  }
  if (event.type == RallyEventType.stageStatusChange) {
    // A road icon rather than the rally's flags, so a glance down the feed
    // separates "the event did something" from "one stage did something".
    return switch (event.status) {
      'running' => Icons.route_outlined,
      'finished' => Icons.done_all_rounded,
      'cancelled' => Icons.block_outlined,
      _ => Icons.route_outlined,
    };
  }
  return switch (event.status) {
    'running' => Icons.play_arrow_rounded,
    'start' => Icons.flag_outlined,
    'paused' => Icons.pause_rounded,
    'lunch break' => Icons.restaurant_outlined,
    'stopped' => Icons.sports_score,
    _ => Icons.tune_rounded,
  };
}

/// The newest entry that still counts — what the hero card shows.
///
/// A retracted entry stays in the feed as history but is ignored by
/// anything deriving current state from it: the organizer has said it
/// shouldn't have been logged, so treating it as "what's happening now"
/// would defeat the point of letting them retract it.
RallyEvent? currentEvent(List<RallyEvent> events) {
  for (final event in events) {
    if (!event.isRetracted) return event;
  }
  return null;
}

/// The event that closes an open-ended one (a pause's end), given the feed
/// is newest-first. Skips retracted entries for the same reason: a mis-tap
/// that was withdrawn shouldn't be what decides how long the rally paused.
RallyEvent? closingEventFor(List<RallyEvent> events, int index) {
  for (var i = index - 1; i >= 0; i--) {
    if (!events[i].isRetracted) return events[i];
  }
  return null;
}

/// The line under an event's label.
///
/// Pause-type events are the interesting case: while one is still the
/// newest event it's *ongoing*, so it shows the organizer's estimate if
/// they set one; once something else has happened since, its real end is
/// simply that next event's time — which means the finished range comes
/// for free, with no second write and nothing in the log ever being
/// edited after the fact.
String eventBodyText(RallyEvent event, {RallyEvent? nextInTime}) {
  if (!event.isOngoingKind) return event.title;

  final start = DateFormat.Hm().format(event.occurredAt);
  if (nextInTime == null) {
    final estimate = event.estimatedEndAt;
    if (estimate != null) {
      return 'est. $start – ${DateFormat.Hm().format(estimate)}';
    }
    return 'since $start';
  }

  final end = nextInTime.occurredAt;
  return '$start – ${DateFormat.Hm().format(end)} · '
      '${formatDuration(end.difference(event.occurredAt))}';
}

String formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 1) return 'under a min';
  if (minutes < 60) return '$minutes min';
  final hours = duration.inHours;
  final remainder = minutes - hours * 60;
  return remainder == 0 ? '$hours h' : '$hours h $remainder min';
}
