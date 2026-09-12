import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/stages_cubit.dart';
import '../bloc/stages_state.dart';
import '../data/rally_repository.dart';
import 'route_editor_page.dart';

class StagesPage extends StatelessWidget {
  const StagesPage({super.key, required this.rallyId});

  final String rallyId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StagesCubit(RallyRepository(), rallyId),
      child: const _StagesView(),
    );
  }
}

class _StagesView extends StatelessWidget {
  const _StagesView();

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
                      subtitle: Text(
                        stage.route.isEmpty
                            ? 'No route yet'
                            : '${stage.route.length} points',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BlocProvider.value(
                              value: context.read<StagesCubit>(),
                              child: RouteEditorPage(stage: stage),
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
}
