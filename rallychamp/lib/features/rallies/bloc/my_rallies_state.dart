import 'package:equatable/equatable.dart';

import '../data/rally_summary.dart';

sealed class MyRalliesState extends Equatable {
  const MyRalliesState();

  @override
  List<Object?> get props => [];
}

class MyRalliesLoading extends MyRalliesState {
  const MyRalliesLoading();
}

class MyRalliesLoaded extends MyRalliesState {
  const MyRalliesLoaded(this.rallies);

  final List<RallySummary> rallies;

  @override
  List<Object?> get props => [rallies];
}

class MyRalliesError extends MyRalliesState {
  const MyRalliesError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
