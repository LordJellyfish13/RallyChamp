import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rallychamp/features/rallies/bloc/checkpoints_cubit.dart';
import 'package:rallychamp/features/rallies/bloc/checkpoints_state.dart';
import 'package:rallychamp/features/rallies/data/checkpoint.dart';
import 'package:rallychamp/features/rallies/data/rally_repository.dart';
import 'package:rallychamp/features/rallies/data/rally_summary.dart';
import 'package:rallychamp/features/rallies/data/stage.dart';

class _FakeRallyRepository implements RallyRepository {
  final _controller = StreamController<List<Checkpoint>>();
  Map<String, Object?>? lastCreate;

  @override
  Future<void> createCheckpoint({
    required String rallyId,
    required String code,
    required CheckpointKind kind,
    GeoPoint? location,
  }) async {
    lastCreate = {
      'rallyId': rallyId,
      'code': code,
      'kind': kind,
      'location': location,
    };
  }

  @override
  Stream<List<Checkpoint>> watchCheckpoints(String rallyId) =>
      _controller.stream;

  @override
  Future<String> createRally({
    required String name,
    required String description,
    required String locationName,
    required DateTime startDate,
    required DateTime endDate,
    required int stageCount,
    required bool publishImmediately,
    bool allowWalkupMarshals = true,
  }) async => 'unused';

  @override
  Stream<List<RallySummary>> watchMyRallies() => const Stream.empty();

  @override
  Future<RallySummary?> getRallySummary(String rallyId) async => null;

  @override
  Future<void> publishRally({
    required String rallyId,
    required String name,
    required String description,
  }) async {}

  @override
  Stream<List<Stage>> watchStages(String rallyId) => const Stream.empty();

  @override
  Future<void> updateStageRoute({
    required String rallyId,
    required String stageId,
    required List<LatLng> route,
  }) async {}

  void emit(List<Checkpoint> checkpoints) => _controller.add(checkpoints);
  void dispose() => _controller.close();
}

void main() {
  group('CheckpointsCubit', () {
    test('starts loading', () async {
      final repo = _FakeRallyRepository();
      final cubit = CheckpointsCubit(repo, 'rally-1');
      expect(cubit.state, isA<CheckpointsLoading>());
      await cubit.close();
      repo.dispose();
    });

    test('emits CheckpointsLoaded when the repository stream emits', () async {
      final repo = _FakeRallyRepository();
      final cubit = CheckpointsCubit(repo, 'rally-1');

      repo.emit([
        const Checkpoint(id: 'c1', code: 'R13', kind: CheckpointKind.viewing),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<CheckpointsLoaded>());
      expect((cubit.state as CheckpointsLoaded).checkpoints, hasLength(1));

      await cubit.close();
      repo.dispose();
    });

    test('addCheckpoint delegates to the repository', () async {
      final repo = _FakeRallyRepository();
      final cubit = CheckpointsCubit(repo, 'rally-1');

      await cubit.addCheckpoint(
        code: 'R13',
        kind: CheckpointKind.viewing,
        location: const GeoPoint(45.3, 14.4),
      );

      expect(repo.lastCreate?['rallyId'], 'rally-1');
      expect(repo.lastCreate?['code'], 'R13');
      expect(repo.lastCreate?['location'], const GeoPoint(45.3, 14.4));

      await cubit.close();
      repo.dispose();
    });
  });
}
