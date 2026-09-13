import 'package:equatable/equatable.dart';

import '../../rallies/data/rally_summary.dart';

sealed class RallyStatusState extends Equatable {
  const RallyStatusState();

  @override
  List<Object?> get props => [];
}

class RallyStatusLoading extends RallyStatusState {
  const RallyStatusLoading();
}

/// [rally] is null if the rally was deleted or became unreadable mid-visit
/// — practically never, but `watchRallySummary` can emit it, so the page
/// falls back to `ActiveRallyCubit`'s last-known summary rather than
/// showing nothing.
class RallyStatusLoaded extends RallyStatusState {
  const RallyStatusLoaded(this.rally);

  final RallySummary? rally;

  @override
  List<Object?> get props => [rally];
}

class RallyStatusError extends RallyStatusState {
  const RallyStatusError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
