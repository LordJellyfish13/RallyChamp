import 'package:equatable/equatable.dart';

sealed class CreateRallyState extends Equatable {
  const CreateRallyState();

  @override
  List<Object?> get props => [];
}

class CreateRallyIdle extends CreateRallyState {
  const CreateRallyIdle();
}

class CreateRallySubmitting extends CreateRallyState {
  const CreateRallySubmitting();
}

class CreateRallySuccess extends CreateRallyState {
  const CreateRallySuccess(this.rallyId);

  final String rallyId;

  @override
  List<Object?> get props => [rallyId];
}

class CreateRallyFailure extends CreateRallyState {
  const CreateRallyFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
