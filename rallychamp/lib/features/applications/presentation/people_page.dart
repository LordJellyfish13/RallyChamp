import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/contact/call_link.dart';
import '../../../core/map/directions_link.dart';
import '../../rallies/data/checkpoint.dart';
import '../../rallies/data/rally_repository.dart';
import '../bloc/people_cubit.dart';
import '../bloc/people_state.dart';
import '../data/applications_repository.dart';
import '../data/staff_application_summary.dart';
import '../data/staff_role.dart';

/// Roster of a rally's accepted marshals/judges, grouped by checkpoint.
/// Reachable by that rally's organizers (from `RallyDetailPage`) and by any
/// other accepted staff member (from the Status page's on-duty banner) —
/// see dev_notes.md §5 "People screen + on-duty assignment banner".
class PeoplePage extends StatelessWidget {
  const PeoplePage({super.key, required this.rallyId});

  final String rallyId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          PeopleCubit(ApplicationsRepository(), RallyRepository(), rallyId),
      child: Scaffold(
        appBar: AppBar(title: const Text('People')),
        body: BlocBuilder<PeopleCubit, PeopleState>(
          builder: (context, state) {
            switch (state) {
              case PeopleLoading():
                return const Center(child: CircularProgressIndicator());
              case PeopleError(:final message):
                return Center(child: Text('Could not load people: $message'));
              case PeopleLoaded(:final staff, :final checkpoints):
                if (staff.isEmpty) {
                  return const Center(
                    child: Text('No accepted staff yet.'),
                  );
                }
                return _PeopleList(staff: staff, checkpoints: checkpoints);
            }
          },
        ),
      ),
    );
  }
}

class _PeopleList extends StatelessWidget {
  const _PeopleList({required this.staff, required this.checkpoints});

  final List<StaffApplicationSummary> staff;
  final List<Checkpoint> checkpoints;

  @override
  Widget build(BuildContext context) {
    final checkpointById = {for (final c in checkpoints) c.id: c};

    final grouped = <Checkpoint?, List<StaffApplicationSummary>>{};
    for (final person in staff) {
      final checkpoint = checkpointById[person.assignedCheckpointId];
      grouped.putIfAbsent(checkpoint, () => []).add(person);
    }

    final assignedGroups = grouped.entries.where((e) => e.key != null).toList()
      ..sort((a, b) => a.key!.code.compareTo(b.key!.code));
    final unassigned = grouped[null] ?? const <StaffApplicationSummary>[];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final entry in assignedGroups)
          _CheckpointGroup(checkpoint: entry.key, people: entry.value),
        if (unassigned.isNotEmpty)
          _CheckpointGroup(checkpoint: null, people: unassigned),
      ],
    );
  }
}

/// Tapping someone in the roster: their number, and where they're posted.
/// Both are things you want at the moment you're trying to reach a
/// specific marshal — calling them, or driving to them — so neither should
/// be a dead end you have to copy out by hand.
class _PersonSheet extends StatelessWidget {
  const _PersonSheet({required this.person, required this.checkpoint});

  final StaffApplicationSummary person;
  final Checkpoint? checkpoint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final location = checkpoint?.location;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(person.applicantName, style: textTheme.titleLarge),
            const SizedBox(height: 4),
            Chip(
              label: Text(
                person.role == StaffRole.judge ? 'Judge' : 'Marshal',
              ),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(height: 16),
            Text(
              checkpoint == null
                  ? 'Not assigned to a checkpoint yet'
                  : 'Posted at ${checkpoint!.code} · ${checkpoint!.kind.label}',
              style: textTheme.bodyMedium,
            ),
            if (checkpoint != null && location == null) ...[
              const SizedBox(height: 4),
              Text(
                'No location set for this checkpoint.',
                style: textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 20),
            if (person.applicantPhone.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => callNumber(person.applicantPhone),
                  icon: const Icon(Icons.call),
                  label: Text('Call ${person.applicantPhone}'),
                ),
              ),
            if (location != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => openDirections(location),
                  icon: const Icon(Icons.directions),
                  label: const Text('Directions to their post'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CheckpointGroup extends StatelessWidget {
  const _CheckpointGroup({required this.checkpoint, required this.people});

  final Checkpoint? checkpoint;
  final List<StaffApplicationSummary> people;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              checkpoint == null
                  ? 'Unassigned'
                  : '${checkpoint!.code} · ${checkpoint!.kind.label}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final person in people)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(person.applicantName),
                subtitle: Text(person.applicantPhone),
                trailing: Chip(
                  label: Text(
                    person.role == StaffRole.judge ? 'Judge' : 'Marshal',
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (_) =>
                      _PersonSheet(person: person, checkpoint: checkpoint),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
