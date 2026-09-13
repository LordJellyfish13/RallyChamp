import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/active_rally/active_rally_cubit.dart';
import '../../../core/active_rally/active_rally_state.dart';
import '../../../core/active_rally/active_rally_switcher.dart';
import '../../../core/active_rally/no_active_rally.dart';
import '../../../core/theme/app_colors.dart';
import '../../applications/data/applications_repository.dart';
import '../../entries/bloc/entries_cubit.dart';
import '../../entries/data/entry.dart';
import '../../entries/presentation/entry_card.dart';
import '../../rallies/bloc/stages_cubit.dart';
import '../../rallies/bloc/stages_state.dart';
import '../../rallies/data/rally_repository.dart';
import '../../rallies/data/stage.dart';
import '../bloc/results_cubit.dart';
import '../data/results_repository.dart';
import '../data/stage_result.dart';
import 'standings_list.dart';

/// One tab answering the same question at two points in time: before the
/// rally, who is competing; during and after, how they're doing. A view
/// picker switches between the start list, the overall standings, and each
/// stage — rather than splitting those across separate screens, which
/// would scatter one topic across the app.
class ResultsPage extends StatelessWidget {
  const ResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ActiveRallyCubit(RallyRepository()),
      child: Scaffold(
        appBar: AppBar(
          title: const ActiveRallySwitcher(fallbackTitle: 'Results'),
        ),
        body: BlocBuilder<ActiveRallyCubit, ActiveRallyState>(
          builder: (context, state) {
            if (state is ActiveRallyLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is! ActiveRallyLoaded || state.active == null) {
              return const NoActiveRally();
            }
            final rally = state.active!;
            return MultiBlocProvider(
              key: ValueKey(rally.id),
              providers: [
                BlocProvider(
                  create: (_) =>
                      EntriesCubit(ApplicationsRepository(), rally.id),
                ),
                BlocProvider(
                  create: (_) => ResultsCubit(ResultsRepository(), rally.id),
                ),
                BlocProvider(
                  create: (_) => StagesCubit(RallyRepository(), rally.id),
                ),
              ],
              child: const _ResultsView(),
            );
          },
        ),
      ),
    );
  }
}

class _ResultsView extends StatefulWidget {
  const _ResultsView();

  @override
  State<_ResultsView> createState() => _ResultsViewState();
}

/// `null` means the start list; otherwise a stage id, or [_overall].
const _overall = '_overall';

class _ResultsViewState extends State<_ResultsView> {
  String? _view;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EntriesCubit, EntriesState>(
      builder: (context, entriesState) {
        if (entriesState is EntriesLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (entriesState is EntriesError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load entries: ${entriesState.message}'),
            ),
          );
        }

        final loaded = entriesState as EntriesLoaded;
        final entries = loaded.accepted;
        final mine = loaded.mine(FirebaseAuth.instance.currentUser?.uid);

        return BlocBuilder<ResultsCubit, ResultsState>(
          builder: (context, resultsState) {
            final results = resultsState is ResultsLoaded
                ? resultsState.results
                : const <StageResult>[];

            return BlocBuilder<StagesCubit, StagesState>(
              builder: (context, stagesState) {
                final stages = stagesState is StagesLoaded
                    ? stagesState.stages
                    : const <Stage>[];
                // Only stages that actually have times are worth offering;
                // an empty tab for a stage that hasn't run is just a dead
                // end to tap on.
                final scored = stages
                    .where((s) => results.any((r) => r.stageId == s.id))
                    .toList();
                // Defaults to the standings once there's anything to rank,
                // and to the start list before that.
                final view = _view ?? (results.isEmpty ? null : _overall);

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (mine.isNotEmpty) _YourEntries(entries: mine),
                    if (results.isNotEmpty)
                      _ViewPicker(
                        stages: scored,
                        selected: view,
                        onChanged: (value) => setState(() => _view = value),
                      ),
                    if (view == null)
                      ..._startList(context, entries)
                    else
                      StandingsList(
                        entries: entries,
                        results: results,
                        stageId: view == _overall ? null : view,
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  List<Widget> _startList(BuildContext context, List<Entry> entries) {
    if (entries.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No entries confirmed yet.\nThe start list appears here once '
            'teams are accepted.',
            textAlign: TextAlign.center,
          ),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
        child: Text(
          '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
      for (final entry in entries) EntryCard(entry: entry),
    ];
  }
}

class _ViewPicker extends StatelessWidget {
  const _ViewPicker({
    required this.stages,
    required this.selected,
    required this.onChanged,
  });

  final List<Stage> stages;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('Start list'),
              selected: selected == null,
              onSelected: (_) => onChanged(null),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Overall'),
              selected: selected == _overall,
              onSelected: (_) => onChanged(_overall),
            ),
            for (final stage in stages) ...[
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(stage.name),
                selected: selected == stage.id,
                onSelected: (_) => onChanged(stage.id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The entrant's own entries and where they stand. An accepted one already
/// appears in the start list below, but pending and rejected ones appear
/// nowhere at all — so without this, filling in the form and waiting looks
/// exactly like the form having gone missing.
class _YourEntries extends StatelessWidget {
  const _YourEntries({required this.entries});

  final List<Entry> entries;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.primaryTint,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entries.length == 1 ? 'Your entry' : 'Your entries',
              style: textTheme.titleMedium?.copyWith(
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '#${entry.carNumber} · ${entry.driverName}',
                        style: textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      switch (entry.status) {
                        EntryStatus.accepted => 'On the start list',
                        EntryStatus.rejected => 'Not accepted',
                        EntryStatus.pending => 'Waiting on the organizer',
                      },
                      style: textTheme.bodySmall?.copyWith(
                        color: switch (entry.status) {
                          EntryStatus.accepted => AppColors.statusRunningText,
                          EntryStatus.rejected => AppColors.inkSoft,
                          EntryStatus.pending => AppColors.primaryDark,
                        },
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
