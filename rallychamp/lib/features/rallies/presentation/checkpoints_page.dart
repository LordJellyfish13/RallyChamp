import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/map/app_map_interaction.dart';
import '../bloc/checkpoints_cubit.dart';
import '../bloc/checkpoints_state.dart';
import '../bloc/stages_cubit.dart';
import '../bloc/stages_state.dart';
import '../data/checkpoint.dart';
import '../data/rally_repository.dart';
import '../data/stage.dart';
import 'checkpoint_form_dialog.dart';

class CheckpointsPage extends StatelessWidget {
  const CheckpointsPage({super.key, required this.rallyId});

  final String rallyId;

  @override
  Widget build(BuildContext context) {
    // Stages come along too: a checkpoint's code only means anything
    // alongside the stage it's on (three stages can each have an "R1").
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => CheckpointsCubit(RallyRepository(), rallyId)),
        BlocProvider(create: (_) => StagesCubit(RallyRepository(), rallyId)),
      ],
      child: const _CheckpointsView(),
    );
  }
}

IconData _iconFor(CheckpointKind kind) {
  return switch (kind) {
    CheckpointKind.viewing => Icons.visibility_outlined,
    CheckpointKind.parking => Icons.local_parking_outlined,
    CheckpointKind.box => Icons.garage_outlined,
  };
}

class _CheckpointsView extends StatelessWidget {
  const _CheckpointsView();

  Future<void> _showAddDialog(
    BuildContext context,
    List<Stage> stages,
    List<Checkpoint> checkpoints,
  ) async {
    final cubit = context.read<CheckpointsCubit>();
    final result = await showCheckpointFormDialog(
      context,
      stages: stages,
      existingCheckpoints: checkpoints,
    );
    if (result == null) return;
    try {
      await cubit.addCheckpoint(
        code: result.code,
        kind: result.kind,
        stageId: result.stageId,
        location: result.location,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add checkpoint: $e')));
      }
    }
  }

  void _openDetail(
    BuildContext context,
    Checkpoint checkpoint,
    List<Stage> stages,
    List<Checkpoint> checkpoints,
  ) {
    final cubit = context.read<CheckpointsCubit>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _CheckpointDetailSheet(
          cubit: cubit,
          checkpoint: checkpoint,
          stages: stages,
          checkpoints: checkpoints,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StagesCubit, StagesState>(
      builder: (context, stagesState) {
        final stages = stagesState is StagesLoaded
            ? stagesState.stages
            : const <Stage>[];
        return BlocBuilder<CheckpointsCubit, CheckpointsState>(
          builder: (context, state) {
            final checkpoints = state is CheckpointsLoaded
                ? state.checkpoints
                : const <Checkpoint>[];
            return Scaffold(
              appBar: AppBar(title: const Text('Checkpoints')),
              floatingActionButton: FloatingActionButton(
                tooltip: 'Add checkpoint',
                onPressed: () => _showAddDialog(context, stages, checkpoints),
                child: const Icon(Icons.add),
              ),
              body: switch (state) {
                CheckpointsLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
                CheckpointsError(:final message) => Center(
                  child: Text('Could not load checkpoints: $message'),
                ),
                CheckpointsLoaded() when checkpoints.isEmpty => const Center(
                  child: Text('No checkpoints yet — tap + to add one.'),
                ),
                CheckpointsLoaded() => _GroupedCheckpoints(
                  checkpoints: checkpoints,
                  stages: stages,
                  onTap: (checkpoint) =>
                      _openDetail(context, checkpoint, stages, checkpoints),
                ),
              },
            );
          },
        );
      },
    );
  }
}

/// Grouped under a header per stage, because the code alone doesn't
/// identify a checkpoint — each stage numbers its own from R1, so a
/// three-stage rally has three of them and a flat list is unreadable.
class _GroupedCheckpoints extends StatelessWidget {
  const _GroupedCheckpoints({
    required this.checkpoints,
    required this.stages,
    required this.onTap,
  });

  final List<Checkpoint> checkpoints;
  final List<Stage> stages;
  final void Function(Checkpoint) onTap;

  @override
  Widget build(BuildContext context) {
    final grouped = <String?, List<Checkpoint>>{};
    for (final checkpoint in checkpoints) {
      grouped.putIfAbsent(checkpoint.stageId, () => []).add(checkpoint);
    }

    bool orphaned(String? stageId) =>
        stageId == null || !stages.any((stage) => stage.id == stageId);

    final leftovers = [
      for (final entry in grouped.entries)
        if (orphaned(entry.key)) ...entry.value,
    ];

    final ordered = <(String, List<Checkpoint>)>[
      for (final stage in stages)
        if (grouped.containsKey(stage.id)) (stage.name, grouped[stage.id]!),
      // Checkpoints created before stages were recorded, plus any pointing
      // at a stage that has since been deleted.
      if (leftovers.isNotEmpty) ('No stage set', leftovers),
    ];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final (stageName, group) in ordered) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(
              stageName,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final checkpoint in group)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(_iconFor(checkpoint.kind)),
                title: Text(checkpoint.code),
                subtitle: Text(
                  checkpoint.location == null
                      ? checkpoint.kind.label
                      : '${checkpoint.kind.label} · location set',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onTap(checkpoint),
              ),
            ),
        ],
      ],
    );
  }
}

class _CheckpointDetailSheet extends StatelessWidget {
  const _CheckpointDetailSheet({
    required this.cubit,
    required this.checkpoint,
    required this.stages,
    required this.checkpoints,
  });

  final CheckpointsCubit cubit;
  final Checkpoint checkpoint;
  final List<Stage> stages;
  final List<Checkpoint> checkpoints;

  Future<void> _edit(BuildContext context) async {
    final result = await showCheckpointFormDialog(
      context,
      title: 'Edit checkpoint',
      submitLabel: 'Save',
      initialCode: checkpoint.code,
      initialKind: checkpoint.kind,
      initialLocation: checkpoint.location,
      stages: stages,
      existingCheckpoints: checkpoints,
      initialStageId: checkpoint.stageId,
    );
    if (result == null) return;
    try {
      await cubit.updateCheckpoint(
        checkpointId: checkpoint.id,
        code: result.code,
        kind: result.kind,
        stageId: result.stageId,
        location: result.location,
      );
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update checkpoint: $e')),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${checkpoint.code}?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await cubit.deleteCheckpoint(checkpoint.id);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete checkpoint: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = checkpoint.location;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Icon(_iconFor(checkpoint.kind), color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checkpoint.code,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Chip(
                        label: Text(checkpoint.kind.label),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (location != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 180,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(location.latitude, location.longitude),
                      initialZoom: 15,
                      interactionOptions: appMapInteractionOptions,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.rallychamp',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(location.latitude, location.longitude),
                            width: 32,
                            height: 32,
                            child: Icon(
                              _iconFor(checkpoint.kind),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              Text(
                'No location set yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _edit(context),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    onPressed: () => _delete(context),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
