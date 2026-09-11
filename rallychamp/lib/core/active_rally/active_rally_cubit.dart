import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/rallies/data/rally_repository.dart';
import 'active_rally_state.dart';
import 'my_rallies_store.dart';

/// Resolves the rally ids in `MyRalliesStore` into displayable
/// `RallySummary`s for the Map/Status/Results switcher. Each of those pages
/// creates its own instance rather than sharing one — `MainScreen` rebuilds
/// a tab's subtree fresh every time you switch to it (no `IndexedStack`),
/// so there's nothing to keep in sync live across tabs; re-reading the
/// persisted store order on each `load()` is what keeps them consistent.
class ActiveRallyCubit extends Cubit<ActiveRallyState> {
  ActiveRallyCubit(this._repository) : super(const ActiveRallyLoading()) {
    load();
  }

  final RallyRepository _repository;

  Future<void> load() async {
    emit(const ActiveRallyLoading());
    final ids = await MyRalliesStore.rallyIds();
    final rallies = await Future.wait(ids.map(_repository.getRallySummary));
    emit(ActiveRallyLoaded(rallies.nonNulls.toList()));
  }

  /// Promotes [rallyId] to the front (the active slot) and reloads.
  Future<void> select(String rallyId) async {
    await MyRalliesStore.recordVisit(rallyId);
    await load();
  }
}
