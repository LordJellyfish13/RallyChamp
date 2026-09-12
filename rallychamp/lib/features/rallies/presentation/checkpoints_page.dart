import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/map/app_map_interaction.dart';
import '../bloc/checkpoints_cubit.dart';
import '../bloc/checkpoints_state.dart';
import '../data/checkpoint.dart';
import '../data/rally_repository.dart';
import 'checkpoint_form_dialog.dart';

class CheckpointsPage extends StatelessWidget {
  const CheckpointsPage({super.key, required this.rallyId});

  final String rallyId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CheckpointsCubit(RallyRepository(), rallyId),
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

  Future<void> _showAddDialog(BuildContext context) async {
    final cubit = context.read<CheckpointsCubit>();
    final result = await showCheckpointFormDialog(context);
    if (result == null) return;
    try {
      await cubit.addCheckpoint(
        code: result.code,
        kind: result.kind,
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

  void _openDetail(BuildContext context, Checkpoint checkpoint) {
    final cubit = context.read<CheckpointsCubit>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _CheckpointDetailSheet(cubit: cubit, checkpoint: checkpoint);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkpoints')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add checkpoint',
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<CheckpointsCubit, CheckpointsState>(
        builder: (context, state) {
          switch (state) {
            case CheckpointsLoading():
              return const Center(child: CircularProgressIndicator());
            case CheckpointsError(:final message):
              return Center(child: Text('Could not load checkpoints: $message'));
            case CheckpointsLoaded(:final checkpoints):
              if (checkpoints.isEmpty) {
                return const Center(
                  child: Text('No checkpoints yet — tap + to add one.'),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: checkpoints.length,
                itemBuilder: (context, index) {
                  final checkpoint = checkpoints[index];
                  return Card(
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
                      onTap: () => _openDetail(context, checkpoint),
                    ),
                  );
                },
              );
          }
        },
      ),
    );
  }
}

class _CheckpointDetailSheet extends StatelessWidget {
  const _CheckpointDetailSheet({required this.cubit, required this.checkpoint});

  final CheckpointsCubit cubit;
  final Checkpoint checkpoint;

  Future<void> _edit(BuildContext context) async {
    final result = await showCheckpointFormDialog(
      context,
      title: 'Edit checkpoint',
      submitLabel: 'Save',
      initialCode: checkpoint.code,
      initialKind: checkpoint.kind,
      initialLocation: checkpoint.location,
    );
    if (result == null) return;
    try {
      await cubit.updateCheckpoint(
        checkpointId: checkpoint.id,
        code: result.code,
        kind: result.kind,
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
