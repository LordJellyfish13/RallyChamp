import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallychamp/features/rallies/bloc/checkpoints_cubit.dart';
import 'package:rallychamp/features/rallies/bloc/checkpoints_state.dart';
import 'package:rallychamp/features/rallies/data/checkpoint.dart';
import 'package:rallychamp/features/rallies/data/rally_repository.dart';

class _FakeRallyRepository extends Fake implements RallyRepository {
  final _controller = StreamController<List<Checkpoint>>();
  Map<String, Object?>? lastCreate;
  Map<String, Object?>? lastUpdate;
  String? lastDeletedId;

  @override
  Future<void> createCheckpoint({
    required String rallyId,
    required String code,
    required CheckpointKind kind,
    String? stageId,
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
  Future<void> updateCheckpoint({
    required String rallyId,
    required String checkpointId,
    required String code,
    required CheckpointKind kind,
    String? stageId,
    GeoPoint? location,
  }) async {
    lastUpdate = {
      'rallyId': rallyId,
      'checkpointId': checkpointId,
      'code': code,
      'kind': kind,
      'location': location,
    };
  }

  @override
  Future<void> deleteCheckpoint({
    required String rallyId,
    required String checkpointId,
  }) async {
    lastDeletedId = checkpointId;
  }

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

    test('updateCheckpoint delegates to the repository', () async {
      final repo = _FakeRallyRepository();
      final cubit = CheckpointsCubit(repo, 'rally-1');

      await cubit.updateCheckpoint(
        checkpointId: 'c1',
        code: 'R14',
        kind: CheckpointKind.parking,
        location: const GeoPoint(45.3, 14.4),
      );

      expect(repo.lastUpdate?['rallyId'], 'rally-1');
      expect(repo.lastUpdate?['checkpointId'], 'c1');
      expect(repo.lastUpdate?['code'], 'R14');
      expect(repo.lastUpdate?['kind'], CheckpointKind.parking);

      await cubit.close();
      repo.dispose();
    });

    test('deleteCheckpoint delegates to the repository', () async {
      final repo = _FakeRallyRepository();
      final cubit = CheckpointsCubit(repo, 'rally-1');

      await cubit.deleteCheckpoint('c1');

      expect(repo.lastDeletedId, 'c1');

      await cubit.close();
      repo.dispose();
    });
  });
}
