import 'package:equatable/equatable.dart';

import '../data/incident.dart';

sealed class IncidentsState extends Equatable {
  const IncidentsState();

  @override
  List<Object?> get props => [];
}

class IncidentsLoading extends IncidentsState {
  const IncidentsLoading();
}

class IncidentsLoaded extends IncidentsState {
  const IncidentsLoaded(this.incidents);

  final List<Incident> incidents;

  List<Incident> get open =>
      incidents.where((incident) => !incident.isResolved).toList();

  @override
  List<Object?> get props => [incidents];
}

/// Expected for anyone who isn't staff on this rally — the security rule
/// denies the read, which is the design working, not a failure to show the
/// user. Callers render nothing rather than an error for that case.
class IncidentsError extends IncidentsState {
  const IncidentsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
