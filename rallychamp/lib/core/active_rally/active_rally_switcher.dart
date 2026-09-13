import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/rallies/data/rally_summary.dart';
import 'active_rally_cubit.dart';
import 'active_rally_state.dart';

/// Drop-in `AppBar` title for the Map/Status/Results tabs: shows the active
/// rally's name, or [fallbackTitle] if nobody's followed/applied to one yet.
/// With more than one tracked rally it's tappable, opening a sheet to
/// switch which one is active. Reads `ActiveRallyCubit` from an ancestor
/// `BlocProvider` — see that class's doc comment for why each page owns its
/// own instance rather than sharing one.
class ActiveRallySwitcher extends StatelessWidget {
  const ActiveRallySwitcher({super.key, required this.fallbackTitle});

  final String fallbackTitle;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveRallyCubit, ActiveRallyState>(
      builder: (context, state) {
        if (state is! ActiveRallyLoaded || state.rallies.isEmpty) {
          return Text(fallbackTitle);
        }
        final active = state.active!;
        final canSwitch = state.rallies.length > 1;
        return InkWell(
          onTap: canSwitch ? () => _openSwitcher(context, state.rallies) : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(active.name, overflow: TextOverflow.ellipsis),
              ),
              if (canSwitch) ...[
                const SizedBox(width: 4),
                const Icon(Icons.expand_more),
              ],
            ],
          ),
        );
      },
    );
  }

  void _openSwitcher(BuildContext context, List<RallySummary> rallies) {
    final cubit = context.read<ActiveRallyCubit>();
    final activeId = rallies.first.id;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final rally in rallies)
                ListTile(
                  title: Text(rally.name),
                  subtitle: Text(rallyStatusLabel(rally.status)),
                  trailing: rally.id == activeId
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    cubit.select(rally.id);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
