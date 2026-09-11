import 'package:equatable/equatable.dart';

import '../data/checkpoint.dart';

sealed class CheckpointsState extends Equatable {
  const CheckpointsState();

  @override
  List<Object?> get props => [];
}

class CheckpointsLoading extends CheckpointsState {
  const CheckpointsLoading();
}

class CheckpointsLoaded extends CheckpointsState {
  const CheckpointsLoaded(this.checkpoints);

  final List<Checkpoint> checkpoints;

  @override
  List<Object?> get props => [checkpoints];
}

class CheckpointsError extends CheckpointsState {
  const CheckpointsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
