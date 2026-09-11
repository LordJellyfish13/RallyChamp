import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/location/current_position.dart';
import '../bloc/checkpoints_cubit.dart';
import '../bloc/checkpoints_state.dart';
import '../data/checkpoint.dart';
import '../data/rally_repository.dart';
import 'location_picker_page.dart';

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

class _CheckpointsView extends StatelessWidget {
  const _CheckpointsView();

  Future<void> _showAddDialog(BuildContext context) async {
    final cubit = context.read<CheckpointsCubit>();
    final codeController = TextEditingController();
    var selectedKind = CheckpointKind.viewing;
    GeoPoint? capturedLocation;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            var locating = false;
            String? locationError;

            Future<void> captureLocation() async {
              setState(() {
                locating = true;
                locationError = null;
              });
              try {
                final position = await currentPosition();
                capturedLocation = GeoPoint(
                  position.latitude,
                  position.longitude,
                );
              } catch (e) {
                locationError = '$e';
              }
              setState(() => locating = false);
            }

            Future<void> dropPin() async {
              final picked = await Navigator.of(dialogContext).push<GeoPoint>(
                MaterialPageRoute<GeoPoint>(
                  builder: (_) =>
                      LocationPickerPage(initialLocation: capturedLocation),
                ),
              );
              if (picked != null) {
                setState(() => capturedLocation = picked);
              }
            }

            return AlertDialog(
              title: const Text('Add checkpoint'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: codeController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      hintText: 'e.g. R13',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<CheckpointKind>(
                    initialValue: selectedKind,
                    decoration: const InputDecoration(labelText: 'Kind'),
                    items: CheckpointKind.values
                        .map(
                          (kind) => DropdownMenuItem(
                            value: kind,
                            child: Text(kind.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedKind = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: locating ? null : captureLocation,
                    icon: locating
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(
                      capturedLocation == null
                          ? 'Use current location'
                          : 'Location captured',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: dropPin,
                    icon: const Icon(Icons.edit_location_alt_outlined),
                    label: const Text('Drop pin on map'),
                  ),
                  if (locationError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      locationError!,
                      style: Theme.of(dialogContext).textTheme.bodySmall
                          ?.copyWith(color: Theme.of(dialogContext).colorScheme.error),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && codeController.text.trim().isNotEmpty) {
      try {
        await cubit.addCheckpoint(
          code: codeController.text.trim(),
          kind: selectedKind,
          location: capturedLocation,
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not add checkpoint: $e')),
          );
        }
      }
    }
  }

  IconData _iconFor(CheckpointKind kind) {
    return switch (kind) {
      CheckpointKind.viewing => Icons.visibility_outlined,
      CheckpointKind.parking => Icons.local_parking_outlined,
      CheckpointKind.box => Icons.garage_outlined,
    };
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
