import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallychamp/features/incidents/bloc/incidents_cubit.dart';
import 'package:rallychamp/features/incidents/bloc/incidents_state.dart';
import 'package:rallychamp/features/incidents/data/incident.dart';
import 'package:rallychamp/features/incidents/data/incident_repository.dart';

class _FakeIncidentRepository implements IncidentRepository {
  final _controller = StreamController<List<Incident>>();
  Map<String, Object?>? lastStatusUpdate;

  @override
  Stream<List<Incident>> watchIncidents(String rallyId) => _controller.stream;

  @override
  Stream<Incident?> watchIncident(String rallyId, String incidentId) =>
      const Stream.empty();

  @override
  Future<({String eventId, String incidentId})> reportIncident({
    required String rallyId,
    required String reporterName,
    required String reporterPhone,
    required bool crewOk,
    required bool roadBlocked,
    required List<HelpKind> helpRequested,
    String? checkpointId,
    String? checkpointCode,
    GeoPoint? location,
    String? note,
  }) async => (incidentId: 'incident-1', eventId: 'event-1');

  @override
  Future<String?> updateStatus({
    required String rallyId,
    required Incident incident,
    required IncidentStatus status,
    String? checkpointCode,
  }) async {
    lastStatusUpdate = {'incidentId': incident.id, 'status': status};
    // Only resolving posts a public all-clear row.
    return status == IncidentStatus.resolved ? 'event-2' : null;
  }

  void emit(List<Incident> incidents) => _controller.add(incidents);
  void dispose() => _controller.close();
}

Incident _incident({
  String id = 'i1',
  IncidentStatus status = IncidentStatus.open,
}) {
  return Incident(
    id: id,
    reporterUid: 'u1',
    reporterName: 'Ana',
    reporterPhone: '0911234567',
    crewOk: true,
    roadBlocked: false,
    helpRequested: const [HelpKind.ambulance],
    status: status,
    createdAt: DateTime(2026, 9, 13, 11, 0),
  );
}

void main() {
  group('IncidentsCubit', () {
    test('starts loading', () async {
      final repo = _FakeIncidentRepository();
      final cubit = IncidentsCubit(repo, 'rally-1');

      expect(cubit.state, isA<IncidentsLoading>());

      await cubit.close();
      repo.dispose();
    });

    test('emits Loaded when the stream emits', () async {
      final repo = _FakeIncidentRepository();
      final cubit = IncidentsCubit(repo, 'rally-1');

      repo.emit([_incident()]);
      await Future<void>.delayed(Duration.zero);

      expect((cubit.state as IncidentsLoaded).incidents, hasLength(1));

      await cubit.close();
      repo.dispose();
    });

    test('open filters out resolved incidents', () async {
      final repo = _FakeIncidentRepository();
      final cubit = IncidentsCubit(repo, 'rally-1');

      repo.emit([
        _incident(id: 'i1'),
        _incident(id: 'i2', status: IncidentStatus.resolved),
        _incident(id: 'i3', status: IncidentStatus.responding),
      ]);
      await Future<void>.delayed(Duration.zero);

      final open = (cubit.state as IncidentsLoaded).open;
      expect(open.map((i) => i.id), ['i1', 'i3']);

      await cubit.close();
      repo.dispose();
    });

    test('updateStatus delegates to the repository', () async {
      final repo = _FakeIncidentRepository();
      final cubit = IncidentsCubit(repo, 'rally-1');

      await cubit.updateStatus(
        incident: _incident(),
        status: IncidentStatus.responding,
      );

      expect(repo.lastStatusUpdate?['incidentId'], 'i1');
      expect(repo.lastStatusUpdate?['status'], IncidentStatus.responding);

      await cubit.close();
      repo.dispose();
    });

    test('byId finds a loaded incident and null for anything else', () async {
      final repo = _FakeIncidentRepository();
      final cubit = IncidentsCubit(repo, 'rally-1');

      repo.emit([_incident(id: 'i1'), _incident(id: 'i2')]);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.byId('i2')?.id, 'i2');
      expect(cubit.byId('nope'), isNull);

      await cubit.close();
      repo.dispose();
    });
  });
}
