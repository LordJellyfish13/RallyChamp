import 'package:equatable/equatable.dart';

import '../../applications/data/staff_application_summary.dart';
import '../../rallies/data/checkpoint.dart';

sealed class MyAssignmentState extends Equatable {
  const MyAssignmentState();

  @override
  List<Object?> get props => [];
}

class MyAssignmentLoading extends MyAssignmentState {
  const MyAssignmentLoading();
}

/// [application] is null unless the signed-in user has an *accepted* staff
/// application for this rally — the Status page banner simply doesn't
/// render otherwise (never applied, still pending, or rejected). Non-null
/// [application] with a null [checkpoint] means accepted but not yet
/// assigned to one.
class MyAssignmentLoaded extends MyAssignmentState {
  const MyAssignmentLoaded({this.application, this.checkpoint});

  final StaffApplicationSummary? application;
  final Checkpoint? checkpoint;

  @override
  List<Object?> get props => [application, checkpoint];
}

class MyAssignmentError extends MyAssignmentState {
  const MyAssignmentError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
