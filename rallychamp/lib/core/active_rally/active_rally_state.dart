import 'package:equatable/equatable.dart';

import '../../features/rallies/data/rally_summary.dart';

sealed class ActiveRallyState extends Equatable {
  const ActiveRallyState();

  @override
  List<Object?> get props => [];
}

class ActiveRallyLoading extends ActiveRallyState {
  const ActiveRallyLoading();
}

/// [rallies] is ordered most-recently-active first (mirrors
/// `MyRalliesStore`'s order) — the head of the list *is* the active rally,
/// so there's no separate "which one is active" field to keep in sync.
/// Empty means nobody's followed or applied to a rally on this device yet.
class ActiveRallyLoaded extends ActiveRallyState {
  const ActiveRallyLoaded(this.rallies);

  final List<RallySummary> rallies;

  RallySummary? get active => rallies.isEmpty ? null : rallies.first;

  @override
  List<Object?> get props => [rallies];
}
