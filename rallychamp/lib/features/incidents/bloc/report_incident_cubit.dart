import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/notifications/push_sender.dart';
import '../data/incident.dart';
import '../data/incident_repository.dart';

sealed class ReportIncidentState extends Equatable {
  const ReportIncidentState();

  @override
  List<Object?> get props => [];
}

class ReportIncidentIdle extends ReportIncidentState {
  const ReportIncidentIdle();
}

class ReportIncidentSubmitting extends ReportIncidentState {
  const ReportIncidentSubmitting();
}

class ReportIncidentSuccess extends ReportIncidentState {
  const ReportIncidentSuccess();
}

class ReportIncidentFailure extends ReportIncidentState {
  const ReportIncidentFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class ReportIncidentCubit extends Cubit<ReportIncidentState> {
  ReportIncidentCubit(this._repository, this.rallyId)
    : super(const ReportIncidentIdle());

  final IncidentRepository _repository;
  final String rallyId;

  Future<void> submit({
    required String reporterName,
    required String reporterPhone,
    required bool crewOk,
    required bool roadBlocked,
    required List<HelpKind> helpRequested,
    String? checkpointId,
    String? checkpointCode,
    GeoPoint? location,
    String? note,
  }) async {
    emit(const ReportIncidentSubmitting());
    try {
      final result = await _repository.reportIncident(
        rallyId: rallyId,
        reporterName: reporterName,
        reporterPhone: reporterPhone,
        crewOk: crewOk,
        roadBlocked: roadBlocked,
        helpRequested: helpRequested,
        checkpointId: checkpointId,
        checkpointCode: checkpointCode,
        location: location,
        note: note,
      );
      // The report is already filed at this point; the push is a bonus
      // that must never turn a successful report into a failed one.
      await requestPush(rallyId: rallyId, eventId: result.eventId);
      emit(const ReportIncidentSuccess());
    } catch (e) {
      emit(ReportIncidentFailure('$e'));
    }
  }
}
