import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../bloc/my_rallies_cubit.dart';
import '../bloc/my_rallies_state.dart';
import '../data/rally_repository.dart';
import '../data/rally_summary.dart';

class MyRalliesPage extends StatelessWidget {
  const MyRalliesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MyRalliesCubit(RallyRepository()),
      child: const _MyRalliesView(),
    );
  }
}

class _MyRalliesView extends StatelessWidget {
  const _MyRalliesView();

  Future<void> _publish(BuildContext context, RallySummary rally) async {
    try {
      await context.read<MyRalliesCubit>().publishRally(rally);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${rally.name} is now published!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not publish: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Rallies')),
      body: BlocBuilder<MyRalliesCubit, MyRalliesState>(
        builder: (context, state) {
          switch (state) {
            case MyRalliesLoading():
              return const Center(child: CircularProgressIndicator());
            case MyRalliesError(:final message):
              return Center(child: Text('Could not load your rallies: $message'));
            case MyRalliesLoaded(:final rallies):
              if (rallies.isEmpty) {
                return const Center(
                  child: Text('You haven\'t created any rallies yet.'),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: rallies.length,
                itemBuilder: (context, index) {
                  final rally = rallies[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Chip(
                                label: Text(
                                  rally.isDraft ? 'Draft' : 'Published',
                                ),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              const Spacer(),
                              Text(
                                DateFormat.yMMMd().format(rally.createdAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            rally.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(rally.description),
                          if (rally.isDraft) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.tonal(
                                onPressed: () => _publish(context, rally),
                                child: const Text('Publish'),
                              ),
                            ),
                          ],
                        ],
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
