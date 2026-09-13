import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/active_rally/active_rally_cubit.dart';
import '../../../core/active_rally/active_rally_state.dart';
import '../../../core/active_rally/active_rally_switcher.dart';
import '../../../core/active_rally/my_rallies_store.dart';
import '../../../core/active_rally/no_active_rally.dart';
import '../../applications/data/applications_repository.dart';
import '../../rallies/data/rally_event.dart';
import '../../rallies/data/rally_repository.dart';
import '../../rallies/data/rally_summary.dart';
import '../../rallies/presentation/edit_rally_page.dart';
import '../../rallies/presentation/rally_info_sheet.dart';
import '../bloc/event_feed_cubit.dart';
import '../bloc/event_feed_state.dart';
import '../bloc/my_assignment_cubit.dart';
import '../bloc/my_assignment_state.dart';
import '../bloc/rally_status_cubit.dart';
import '../bloc/rally_status_state.dart';
import 'activity_hero_card.dart';
import 'event_log_row.dart';
import 'event_visuals.dart';
import 'on_duty_banner.dart';
import 'status_quick_actions.dart';

class StatusPage extends StatelessWidget {
  const StatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ActiveRallyCubit(RallyRepository()),
      // The builder wraps the whole Scaffold, not just the body, because
      // the AppBar's info action needs the resolved rally too.
      child: BlocBuilder<ActiveRallyCubit, ActiveRallyState>(
        builder: (context, state) {
          final rally = state is ActiveRallyLoaded ? state.active : null;
          return Scaffold(
            appBar: AppBar(
              title: const ActiveRallySwitcher(fallbackTitle: 'Status'),
              actions: [
                if (rally != null)
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    tooltip: 'Rally info',
                    onPressed: () => _openInfo(context, rally),
                  ),
              ],
            ),
            body: Builder(
              builder: (context) {
                if (state is ActiveRallyLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (rally == null) return const NoActiveRally();
                // Everything below is keyed on the active rally's id so using
                // the switcher, without leaving this page, tears down and
                // re-subscribes each cubit for the new rally instead of reusing
                // a `create` closure captured for the old one.
                return MultiBlocProvider(
                  key: ValueKey(rally.id),
                  providers: [
                    BlocProvider(
                      create: (_) =>
                          RallyStatusCubit(RallyRepository(), rally.id),
                    ),
                    BlocProvider(
                      create: (_) => EventFeedCubit(RallyRepository(), rally.id),
                    ),
                    BlocProvider(
                      create: (_) => MyAssignmentCubit(
                        ApplicationsRepository(),
                        RallyRepository(),
                        rally.id,
                      ),
                    ),
                  ],
                  child: _StatusView(fallbackRally: rally),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _openInfo(BuildContext context, RallySummary rally) async {
    final cubit = context.read<ActiveRallyCubit>();
    final navigator = Navigator.of(context);
    final isAdmin = rally.adminUids.contains(
      FirebaseAuth.instance.currentUser?.uid,
    );

    final action = await showRallyInfoSheet(
      context,
      rally: rally,
      isAdmin: isAdmin,
    );
    if (action == null) return;

    switch (action) {
      case RallyInfoAction.edit:
        final changed = await navigator.push<bool>(
          MaterialPageRoute(builder: (_) => EditRallyPage(rally: rally)),
        );
        // The summary the switcher holds is a one-shot read, so an edited
        // name or date would otherwise keep showing the old value until
        // the tab is rebuilt.
        if (changed ?? false) await cubit.load();
      case RallyInfoAction.stopFollowing:
        if (!context.mounted) return;
        final confirmed = await _confirmUnfollow(context, rally);
        if (!confirmed) return;
        await MyRalliesStore.forget(rally.id);
        await cubit.load();
    }
  }

  Future<bool> _confirmUnfollow(
    BuildContext context,
    RallySummary rally,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stop following?'),
        content: Text(
          '${rally.name} will no longer appear on your Map, Status and '
          'Results tabs. Any application or entry you sent the organizer '
          'still stands — this only clears it from your list here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Stop following'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({required this.fallbackRally});

  /// `ActiveRallyCubit`'s one-shot summary, shown until the live stream's
  /// first snapshot lands (near-instant from Firestore's cache) so the page
  /// never flashes empty.
  final RallySummary fallbackRally;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RallyStatusCubit, RallyStatusState>(
      builder: (context, statusState) {
        final rally =
            (statusState is RallyStatusLoaded ? statusState.rally : null) ??
            fallbackRally;
        final isAdmin = rally.adminUids.contains(
          FirebaseAuth.instance.currentUser?.uid,
        );

        return BlocBuilder<EventFeedCubit, EventFeedState>(
          builder: (context, feedState) {
            final events = feedState is EventFeedLoaded
                ? feedState.events
                : const <RallyEvent>[];
            // A rally created before the activity log existed has no events
            // at all, and a brand-new one's first event may not have synced
            // yet — either way the hero still has something true to say.
            final hero =
                currentEvent(events) ??
                syntheticStatusEvent(rally.status, rally.createdAt);
            // Everything except the hero, which is already shown above.
            final rest = events.where((e) => e.id != hero.id).toList();

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                ActivityHeroCard(
                  event: hero,
                  nextInTime: null,
                  rallyStatus: rally.status,
                  actions: isAdmin
                      ? StatusQuickActions(status: rally.status)
                      : null,
                ),
                const _OnDutySection(),
                if (rest.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Activity',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (final event in rest)
                    EventLogRow(
                      event: event,
                      // The feed is newest-first, so what closes a pause is
                      // the nearest *newer* entry that still counts — which
                      // is why this skips retracted ones rather than just
                      // taking the previous index.
                      nextInTime: closingEventFor(
                        events,
                        events.indexOf(event),
                      ),
                      onRetract: isAdmin
                          ? () => _confirmRetract(context, event)
                          : null,
                    ),
                ],
                if (feedState is EventFeedError)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Could not load activity: ${feedState.message}'),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

Future<void> _confirmRetract(BuildContext context, RallyEvent event) async {
  final cubit = context.read<EventFeedCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Retract this entry?'),
      content: Text(
        'It stays in the log, struck through, so the history still shows '
        'it was logged — it just no longer counts. "${event.title}" was '
        'recorded at ${DateFormat.Hm().format(event.occurredAt)}.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Retract'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;
  try {
    await cubit.retract(event.id);
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not retract: $e')),
    );
  }
}

class _OnDutySection extends StatelessWidget {
  const _OnDutySection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RallyStatusCubit, RallyStatusState>(
      builder: (context, statusState) {
        final rally = statusState is RallyStatusLoaded
            ? statusState.rally
            : null;
        if (rally == null || !liveRallyStatuses.contains(rally.status)) {
          return const SizedBox.shrink();
        }
        return BlocBuilder<MyAssignmentCubit, MyAssignmentState>(
          builder: (context, myState) {
            if (myState is! MyAssignmentLoaded || myState.application == null) {
              return const SizedBox.shrink();
            }
            return OnDutyBanner(
              rallyId: rally.id,
              application: myState.application!,
              checkpoint: myState.checkpoint,
            );
          },
        );
      },
    );
  }
}
