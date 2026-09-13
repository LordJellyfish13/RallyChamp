import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/location/current_position.dart';
import '../data/checkpoint.dart';
import '../data/stage.dart';
import 'location_picker_page.dart';

/// What a [showCheckpointFormDialog] submission collected — the caller
/// decides whether that means creating or updating a checkpoint.
class CheckpointFormResult {
  const CheckpointFormResult({
    required this.code,
    required this.kind,
    required this.location,
    this.stageId,
  });

  final String code;
  final CheckpointKind kind;
  final GeoPoint? location;
  final String? stageId;
}

/// The add/edit checkpoint form — shared by `CheckpointsPage` (add and
/// edit, with the "use current location"/"drop pin" capture buttons) and
/// `RouteEditorPage` ("mark this route point as a checkpoint", where the
/// location is already known so those buttons are hidden). Returns null if
/// cancelled.
Future<CheckpointFormResult?> showCheckpointFormDialog(
  BuildContext context, {
  String title = 'Add checkpoint',
  String submitLabel = 'Add',
  String? initialCode,
  CheckpointKind initialKind = CheckpointKind.viewing,
  GeoPoint? initialLocation,
  bool showLocationCapture = true,
  List<Stage> stages = const [],
  List<Checkpoint> existingCheckpoints = const [],
  String? initialStageId,
}) async {
  var selectedStageId =
      initialStageId ?? (stages.isEmpty ? null : stages.first.id);

  // Rally checkpoints run in sequences and each stage restarts the
  // numbering, so the suggestion only ever looks at the selected stage's
  // own codes — otherwise a three-stage rally would suggest R7 for a
  // stage that only has R1 and R2.
  String? suggestionFor(String? stageId) => nextCheckpointCode(
    existingCheckpoints
        .where((checkpoint) => checkpoint.stageId == stageId)
        .map((checkpoint) => checkpoint.code),
  );

  var suggested = initialCode ?? suggestionFor(selectedStageId);
  final codeController = TextEditingController(text: suggested);
  var selectedKind = initialKind;
  var location = initialLocation;

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
              location = GeoPoint(position.latitude, position.longitude);
            } catch (e) {
              locationError = '$e';
            }
            setState(() => locating = false);
          }

          Future<void> dropPin() async {
            final picked = await Navigator.of(dialogContext).push<GeoPoint>(
              MaterialPageRoute<GeoPoint>(
                builder: (_) => LocationPickerPage(initialLocation: location),
              ),
            );
            if (picked != null) setState(() => location = picked);
          }

          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stages.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedStageId,
                    decoration: const InputDecoration(labelText: 'Stage'),
                    items: stages
                        .map(
                          (stage) => DropdownMenuItem(
                            value: stage.id,
                            child: Text(stage.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        selectedStageId = value;
                        // Re-suggests only while the field still holds the
                        // last suggestion — once someone types their own
                        // code, switching stage must not overwrite it.
                        if (codeController.text == (suggested ?? '')) {
                          suggested = suggestionFor(value);
                          codeController.text = suggested ?? '';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
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
                    if (value != null) setState(() => selectedKind = value);
                  },
                ),
                if (showLocationCapture) ...[
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
                      location == null
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
                          ?.copyWith(
                            color: Theme.of(dialogContext).colorScheme.error,
                          ),
                    ),
                  ],
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
                child: Text(submitLabel),
              ),
            ],
          );
        },
      );
    },
  );

  if (result != true || codeController.text.trim().isEmpty) return null;
  return CheckpointFormResult(
    code: codeController.text.trim(),
    kind: selectedKind,
    location: location,
    stageId: selectedStageId,
  );
}
