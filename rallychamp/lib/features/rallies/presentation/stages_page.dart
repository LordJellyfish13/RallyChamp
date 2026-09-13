import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/notifications/push_sender.dart';
import '../../../core/theme/app_colors.dart';
import '../bloc/checkpoints_cubit.dart';
import '../bloc/stages_cubit.dart';
import '../bloc/stages_state.dart';
import '../data/rally_repository.dart';
import '../data/stage.dart';
import 'route_editor_page.dart';

class StagesPage extends StatelessWidget {
  const StagesPage({super.key, required this.rallyId});

  final String rallyId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => StagesCubit(RallyRepository(), rallyId)),
        // Route editing can also mark a route point as a checkpoint — see
        // dev_notes.md §5 "Marking checkpoints while drawing a route" —
        // so this cubit is provided here too, alongside stages.
        BlocProvider(
          create: (_) => CheckpointsCubit(RallyRepository(), rallyId),
        ),
      ],
      child: _StagesView(rallyId: rallyId),
    );
  }
}

class _StagesView extends StatelessWidget {
  const _StagesView({required this.rallyId});

  final String rallyId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stages')),
      body: BlocBuilder<StagesCubit, StagesState>(
        builder: (context, state) {
          switch (state) {
            case StagesLoading():
              return const Center(child: CircularProgressIndicator());
            case StagesError(:final message):
              return Center(child: Text('Could not load stages: $message'));
            case StagesLoaded(:final stages):
              if (stages.isEmpty) {
                return const Center(child: Text('No stages yet.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: stages.length,
                itemBuilder: (context, index) {
                  final stage = stages[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.route_outlined),
                      title: Text(stage.name),
                      subtitle: Row(
                        children: [
                          _StatusChip(status: stage.status),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              [
                                if (stage.scheduledStart != null)
                                  DateFormat.Hm().format(stage.scheduledStart!),
                                if (stage.distanceLabel != null)
                                  stage.distanceLabel!,
                                stage.route.isEmpty
                                    ? 'No route yet'
                                    : '${stage.route.length} points',
                              ].join(' · '),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      // A visible affordance, not a long-press: the row's
                      // tap already belongs to the route editor, and a
                      // hidden gesture advertises itself to nobody.
                      trailing: IconButton(
                        icon: const Icon(Icons.more_vert),
                        tooltip: 'Set stage status',
                        onPressed: () => _pickStatus(context, rallyId, stage),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MultiBlocProvider(
                              providers: [
                                BlocProvider.value(
                                  value: context.read<StagesCubit>(),
                                ),
                                BlocProvider.value(
                                  value: context.read<CheckpointsCubit>(),
                                ),
                              ],
                              child: RouteEditorPage(
                                rallyId: rallyId,
                                stage: stage,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
          }
        },
      ),
    );
  }

  Future<void> _pickStatus(
    BuildContext context,
    String rallyId,
    Stage stage,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showModalBottomSheet<StageStatus>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  stage.name,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
            ),
            for (final status in StageStatus.values)
              ListTile(
                leading: Icon(_iconFor(status)),
                title: Text(status.label),
                trailing: status == stage.status
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(status),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.straighten),
              title: const Text('Length & start time'),
              subtitle: Text(
                [
                  stage.distanceLabel ?? 'No route drawn yet',
                  if (stage.scheduledStart != null)
                    DateFormat.Hm().format(stage.scheduledStart!),
                ].join(' · '),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _editDetails(context, rallyId, stage);
              },
            ),
          ],
        ),
      ),
    );

    if (picked == null || picked == stage.status) return;
    try {
      final eventId = await RallyRepository().updateStageStatus(
        rallyId: rallyId,
        stageId: stage.id,
        stageName: stage.name,
        status: picked,
      );
      // Announced the same way a rally status change is — a marshal
      // waiting at a stage that just went live is exactly who needs to
      // know without opening the app.
      await requestPush(rallyId: rallyId, eventId: eventId);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update the stage: $e')),
      );
    }
  }
}

Future<void> _editDetails(
  BuildContext context,
  String rallyId,
  Stage stage,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await showDialog<({double? distanceKm, DateTime? start})>(
    context: context,
    builder: (_) => _StageDetailsDialog(stage: stage),
  );
  if (result == null) return;
  try {
    await RallyRepository().updateStageDetails(
      rallyId: rallyId,
      stageId: stage.id,
      distanceKm: result.distanceKm,
      scheduledStart: result.start,
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not save the stage details: $e')),
    );
  }
}

/// Length and start time. A StatefulWidget so the text controller's
/// lifetime matches the field's — the same disposal crash the results
/// time sheet hit (dev_notes.md §5 "Results and timing").
class _StageDetailsDialog extends StatefulWidget {
  const _StageDetailsDialog({required this.stage});

  final Stage stage;

  @override
  State<_StageDetailsDialog> createState() => _StageDetailsDialogState();
}

class _StageDetailsDialogState extends State<_StageDetailsDialog> {
  late final _distance = TextEditingController(
    text: widget.stage.distanceKm?.toString() ?? '',
  );
  late DateTime? _start = widget.stage.scheduledStart;
  String? _error;

  @override
  void dispose() {
    _distance.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _start ?? now,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start ?? now),
    );
    if (time == null) return;
    setState(() {
      _start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _save() {
    final raw = _distance.text.trim().replaceAll(',', '.');
    double? km;
    if (raw.isNotEmpty) {
      km = double.tryParse(raw);
      // Rejected rather than silently dropped: a mistyped length that
      // vanished would look like it saved.
      if (km == null || km <= 0) {
        setState(() => _error = 'Enter a length like 12.4, or leave it blank');
        return;
      }
    }
    Navigator.of(context).pop((distanceKm: km, start: _start));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.stage.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _distance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Length override (km)',
              // The measured route length, when there is one, is what's
              // actually used until someone types here — this hint is
              // what tells the organizer that leaving the field blank
              // isn't leaving the stage's length unset.
              hintText: widget.stage.measuredDistanceKm != null
                  ? 'Measured from route: '
                        '${widget.stage.measuredDistanceKm!.toStringAsFixed(1)}'
                  : '12.4',
              helperText: 'Only needed if the published length differs from '
                  'the drawn route. Leave blank to use the route.',
              helperMaxLines: 2,
              errorText: _error,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(
              _start == null
                  ? 'No start time'
                  : DateFormat.yMMMd().add_Hm().format(_start!),
            ),
            trailing: _start == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear start time',
                    onPressed: () => setState(() => _start = null),
                  ),
            onTap: _pickStart,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

IconData _iconFor(StageStatus status) => switch (status) {
  StageStatus.scheduled => Icons.schedule,
  StageStatus.running => Icons.play_arrow_rounded,
  StageStatus.finished => Icons.done_all_rounded,
  StageStatus.cancelled => Icons.block_outlined,
};

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final StageStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = switch (status) {
      StageStatus.scheduled => StatusColors.setup,
      StageStatus.running => StatusColors.running,
      StageStatus.finished => StatusColors.finished,
      StageStatus.cancelled => StatusColors.paused,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.tint,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.text,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
