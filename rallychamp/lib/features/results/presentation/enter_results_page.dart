import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../applications/data/applications_repository.dart';
import '../../entries/bloc/entries_cubit.dart';
import '../../entries/data/entry.dart';
import '../../rallies/bloc/stages_cubit.dart';
import '../../rallies/bloc/stages_state.dart';
import '../../rallies/data/rally_repository.dart';
import '../../rallies/data/stage.dart';
import '../bloc/results_cubit.dart';
import '../data/results_repository.dart';
import '../data/stage_result.dart';

/// Race control's screen: pick a stage, then tap a crew to record their
/// time. Per dev_notes.md §5 the radio call-ins are aggregated by one
/// person who types them in — this is that person's screen, so it's built
/// for speed and for correcting mistakes, not for browsing.
class EnterResultsPage extends StatelessWidget {
  const EnterResultsPage({super.key, required this.rallyId});

  final String rallyId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => StagesCubit(RallyRepository(), rallyId)),
        BlocProvider(
          create: (_) => EntriesCubit(ApplicationsRepository(), rallyId),
        ),
        BlocProvider(
          create: (_) => ResultsCubit(ResultsRepository(), rallyId),
        ),
      ],
      child: const _EnterResultsView(),
    );
  }
}

class _EnterResultsView extends StatefulWidget {
  const _EnterResultsView();

  @override
  State<_EnterResultsView> createState() => _EnterResultsViewState();
}

class _EnterResultsViewState extends State<_EnterResultsView> {
  String? _stageId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter results')),
      body: BlocBuilder<StagesCubit, StagesState>(
        builder: (context, stagesState) {
          final stages = stagesState is StagesLoaded
              ? stagesState.stages
              : const <Stage>[];
          if (stages.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final stageId = _stageId ?? stages.first.id;

          return BlocBuilder<EntriesCubit, EntriesState>(
            builder: (context, entriesState) {
              final entries = entriesState is EntriesLoaded
                  ? entriesState.accepted
                  : const <Entry>[];

              return Column(
                children: [
                  _StagePicker(
                    stages: stages,
                    selectedId: stageId,
                    onChanged: (id) => setState(() => _stageId = id),
                  ),
                  if (entries.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No accepted entries yet — accept teams onto the '
                            'start list before recording times.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: BlocBuilder<ResultsCubit, ResultsState>(
                        builder: (context, resultsState) {
                          return ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: entries.length,
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              final result = resultsState is ResultsLoaded
                                  ? resultsState.forEntryOnStage(
                                      entry.id,
                                      stageId,
                                    )
                                  : null;
                              return _ResultRow(
                                entry: entry,
                                stageId: stageId,
                                result: result,
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _StagePicker extends StatelessWidget {
  const _StagePicker({
    required this.stages,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Stage> stages;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          for (final stage in stages)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(stage.name),
                selected: stage.id == selectedId,
                onSelected: (_) => onChanged(stage.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.entry,
    required this.stageId,
    required this.result,
  });

  final Entry entry;
  final String stageId;
  final StageResult? result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final recorded = result;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.charcoal,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            entry.carNumber,
            style: textTheme.titleMedium?.copyWith(color: AppColors.surface),
          ),
        ),
        title: Text(entry.driverName),
        subtitle: Text(entry.coDriverName),
        trailing: Text(
          recorded == null
              ? '—'
              : recorded.isFinished
              ? formatStageTime(recorded.timeMs!)
              : recorded.status.label,
          style: textTheme.titleMedium?.copyWith(
            color: recorded == null
                ? AppColors.inkSoft
                : recorded.isFinished
                ? AppColors.statusRunningText
                : AppColors.statusStoppedText,
          ),
        ),
        onTap: () => _edit(context),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final cubit = context.read<ResultsCubit>();
    final messenger = ScaffoldMessenger.of(context);

    // The sheet owns its own controller. Creating one here and disposing
    // it when the sheet closes crashes: the TextField is still mounted
    // through the closing animation, and disposing a controller out from
    // under a live field trips a framework assertion.
    final action = await showModalBottomSheet<({ResultStatus? status, int? timeMs})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _TimeSheet(entry: entry, existing: result),
    );

    if (action == null) return;
    if (action.status == null) {
      try {
        await cubit.clear(stageId: stageId, entryId: entry.id);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Could not clear: $e')));
      }
      return;
    }
    await _write(cubit, messenger, status: action.status!, timeMs: action.timeMs);
  }

  Future<void> _write(
    ResultsCubit cubit,
    ScaffoldMessengerState messenger, {
    required ResultStatus status,
    int? timeMs,
  }) async {
    try {
      await cubit.save(
        stageId: stageId,
        entryId: entry.id,
        carNumber: entry.carNumber,
        status: status,
        timeMs: timeMs,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save result: $e')),
      );
    }
  }
}


/// The time entry sheet. A StatefulWidget purely so the controller's
/// lifetime matches the field's — see `_edit`.
class _TimeSheet extends StatefulWidget {
  const _TimeSheet({required this.entry, required this.existing});

  final Entry entry;
  final StageResult? existing;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.existing?.isFinished ?? false
        ? formatStageTime(widget.existing!.timeMs!)
        : '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = parseStageTime(_controller.text);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a time like 4:32.71')),
      );
      return;
    }
    Navigator.of(context).pop((status: ResultStatus.finished, timeMs: parsed));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '#${widget.entry.carNumber} · ${widget.entry.driverName}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Stage time',
              hintText: '4:32.71',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _submit, child: const Text('Save time')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final status in [
                ResultStatus.dnf,
                ResultStatus.dns,
                ResultStatus.dsq,
              ])
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(
                    (status: status, timeMs: null),
                  ),
                  child: Text(status.label),
                ),
              if (widget.existing != null)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(
                    (status: null, timeMs: null),
                  ),
                  child: const Text('Clear'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
