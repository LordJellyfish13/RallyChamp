import 'package:equatable/equatable.dart';

sealed class ApplicationState extends Equatable {
  const ApplicationState();

  @override
  List<Object?> get props => [];
}

class ApplicationIdle extends ApplicationState {
  const ApplicationIdle();
}

class ApplicationSubmitting extends ApplicationState {
  const ApplicationSubmitting();
}

class ApplicationSuccess extends ApplicationState {
  const ApplicationSuccess();
}

class ApplicationFailure extends ApplicationState {
  const ApplicationFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
