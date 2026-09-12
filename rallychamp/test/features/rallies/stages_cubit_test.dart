import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rallychamp/features/rallies/bloc/stages_cubit.dart';
import 'package:rallychamp/features/rallies/bloc/stages_state.dart';
import 'package:rallychamp/features/rallies/data/checkpoint.dart';
import 'package:rallychamp/features/rallies/data/rally_repository.dart';
import 'package:rallychamp/features/rallies/data/rally_summary.dart';
import 'package:rallychamp/features/rallies/data/stage.dart';

class _FakeRallyRepository implements RallyRepository {
  final _controller = StreamController<List<Stage>>();
  Map<String, Object?>? lastSavedRoute;

  @override
  Stream<List<Stage>> watchStages(String rallyId) => _controller.stream;

  @override
  Future<void> updateStageRoute({
    required String rallyId,
    required String stageId,
    required List<LatLng> route,
  }) async {
    lastSavedRoute = {
      'rallyId': rallyId,
      'stageId': stageId,
      'route': route,
    };
  }

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
  Future<void> createCheckpoint({
    required String rallyId,
    required String code,
    required CheckpointKind kind,
    GeoPoint? location,
  }) async {}

  @override
  Stream<List<Checkpoint>> watchCheckpoints(String rallyId) =>
      const Stream.empty();

  void emit(List<Stage> stages) => _controller.add(stages);
  void dispose() => _controller.close();
}

void main() {
  group('StagesCubit', () {
    test('starts loading', () async {
      final repo = _FakeRallyRepository();
      final cubit = StagesCubit(repo, 'rally-1');
      expect(cubit.state, isA<StagesLoading>());
      await cubit.close();
      repo.dispose();
    });

    test('emits StagesLoaded when the repository stream emits', () async {
      final repo = _FakeRallyRepository();
      final cubit = StagesCubit(repo, 'rally-1');

      repo.emit([
        const Stage(id: 's1', name: 'Main stage', order: 0, route: []),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<StagesLoaded>());
      expect((cubit.state as StagesLoaded).stages, hasLength(1));

      await cubit.close();
      repo.dispose();
    });

    test('saveRoute delegates to the repository', () async {
      final repo = _FakeRallyRepository();
      final cubit = StagesCubit(repo, 'rally-1');

      await cubit.saveRoute(
        stageId: 's1',
        route: const [LatLng(45.3, 14.4), LatLng(45.31, 14.41)],
      );

      expect(repo.lastSavedRoute?['rallyId'], 'rally-1');
      expect(repo.lastSavedRoute?['stageId'], 's1');
      expect(repo.lastSavedRoute?['route'], hasLength(2));

      await cubit.close();
      repo.dispose();
    });
  });
}
