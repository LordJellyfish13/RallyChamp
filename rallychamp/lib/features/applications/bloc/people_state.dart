import 'package:equatable/equatable.dart';

import '../../rallies/data/checkpoint.dart';
import '../data/staff_application_summary.dart';

sealed class PeopleState extends Equatable {
  const PeopleState();

  @override
  List<Object?> get props => [];
}

class PeopleLoading extends PeopleState {
  const PeopleLoading();
}

/// [checkpoints] resolves an accepted person's `assignedCheckpointId` to a
/// code/kind for display — it can lag [staff] by a moment (two independent
/// streams), so the roster just re-groups with whatever checkpoint data it
/// currently has rather than waiting on both.
class PeopleLoaded extends PeopleState {
  const PeopleLoaded({required this.staff, required this.checkpoints});

  final List<StaffApplicationSummary> staff;
  final List<Checkpoint> checkpoints;

  @override
  List<Object?> get props => [staff, checkpoints];
}

class PeopleError extends PeopleState {
  const PeopleError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
