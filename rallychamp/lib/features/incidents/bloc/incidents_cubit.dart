import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/notifications/push_sender.dart';
import '../data/incident.dart';
import '../data/incident_repository.dart';
import 'incidents_state.dart';

class IncidentsCubit extends Cubit<IncidentsState> {
  IncidentsCubit(this._repository, this.rallyId)
    : super(const IncidentsLoading()) {
    _subscription = _repository.watchIncidents(rallyId).listen(
      (incidents) => emit(IncidentsLoaded(incidents)),
      onError: (Object error, StackTrace _) {
        if (!isClosed) emit(IncidentsError('$error'));
      },
    );
  }

  final IncidentRepository _repository;
  final String rallyId;
  late final StreamSubscription<List<Incident>> _subscription;

  /// Marks help as dispatched, or the incident as over. Resolving posts a
  /// public all-clear row and nominates it for a (quiet) push, so the
  /// people who got the alert also get told it ended.
  Future<void> updateStatus({
    required Incident incident,
    required IncidentStatus status,
    String? checkpointCode,
  }) async {
    final eventId = await _repository.updateStatus(
      rallyId: rallyId,
      incident: incident,
      status: status,
      checkpointCode: checkpointCode,
    );
    if (eventId != null) {
      await requestPush(rallyId: rallyId, eventId: eventId);
    }
  }

  Incident? byId(String incidentId) {
    final current = state;
    if (current is! IncidentsLoaded) return null;
    for (final incident in current.incidents) {
      if (incident.id == incidentId) return incident;
    }
    return null;
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
