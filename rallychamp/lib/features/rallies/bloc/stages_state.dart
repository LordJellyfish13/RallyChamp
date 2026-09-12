import 'package:equatable/equatable.dart';

import '../data/stage.dart';

sealed class StagesState extends Equatable {
  const StagesState();

  @override
  List<Object?> get props => [];
}

class StagesLoading extends StagesState {
  const StagesLoading();
}

class StagesLoaded extends StagesState {
  const StagesLoaded(this.stages);

  final List<Stage> stages;

  @override
  List<Object?> get props => [stages];
}

class StagesError extends StagesState {
  const StagesError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
