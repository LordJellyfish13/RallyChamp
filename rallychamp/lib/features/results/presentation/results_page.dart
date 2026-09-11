import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/active_rally/active_rally_cubit.dart';
import '../../../core/active_rally/active_rally_state.dart';
import '../../../core/active_rally/active_rally_switcher.dart';
import '../../../core/active_rally/no_active_rally.dart';
import '../../rallies/data/rally_repository.dart';

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
            if (state is! ActiveRallyLoaded || state.active == null) {
              return const NoActiveRally();
            }
            return Center(
              child: Text('Results for ${state.active!.name} coming soon'),
            );
          },
        ),
      ),
    );
  }
}
