import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/active_rally/active_rally_cubit.dart';
import '../../../core/active_rally/active_rally_state.dart';
import '../../../core/active_rally/active_rally_switcher.dart';
import '../../../core/active_rally/no_active_rally.dart';
import '../../rallies/data/rally_repository.dart';

class StatusPage extends StatelessWidget {
  const StatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ActiveRallyCubit(RallyRepository()),
      child: Scaffold(
        appBar: AppBar(
          title: const ActiveRallySwitcher(fallbackTitle: 'Status'),
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
            return Center(
              child: Text('${rally.name} — status: ${rally.status}'),
            );
          },
        ),
      ),
    );
  }
}
