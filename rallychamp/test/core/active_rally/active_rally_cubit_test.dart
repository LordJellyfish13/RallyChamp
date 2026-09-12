import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rallychamp/core/active_rally/active_rally_cubit.dart';
import 'package:rallychamp/core/active_rally/active_rally_state.dart';
import 'package:rallychamp/core/active_rally/my_rallies_store.dart';
import 'package:rallychamp/features/rallies/data/checkpoint.dart';
import 'package:rallychamp/features/rallies/data/rally_repository.dart';
import 'package:rallychamp/features/rallies/data/rally_summary.dart';
import 'package:rallychamp/features/rallies/data/stage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRallyRepository implements RallyRepository {
  final Map<String, RallySummary> summaries = {};

  @override
  Future<RallySummary?> getRallySummary(String rallyId) async =>
      summaries[rallyId];

  @override
  Stream<List<Stage>> watchStages(String rallyId) => const Stream.empty();

  @override
  Future<void> updateCheckpoint({
    required String rallyId,
    required String checkpointId,
    required String code,
    required CheckpointKind kind,
    GeoPoint? location,
  }) async {}

  @override
  Future<void> deleteCheckpoint({
    required String rallyId,
    required String checkpointId,
  }) async {}

  @override
  Future<void> updateStageRoute({
    required String rallyId,
    required String stageId,
    required List<LatLng> route,
  }) async {}

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
}

RallySummary _summary(String id, String name) {
  return RallySummary(
    id: id,
    name: name,
    description: '',
    visibility: 'published',
    status: 'running',
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('ActiveRallyCubit', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads an empty list when nothing has been followed', () async {
      final cubit = ActiveRallyCubit(_FakeRallyRepository());
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as ActiveRallyLoaded;
      expect(state.rallies, isEmpty);
      expect(state.active, isNull);

      await cubit.close();
    });

    test('resolves stored ids into summaries, most-recent first', () async {
      await MyRalliesStore.recordVisit('r1');
      await MyRalliesStore.recordVisit('r2');

      final repo = _FakeRallyRepository()
        ..summaries['r1'] = _summary('r1', 'Prva rally')
        ..summaries['r2'] = _summary('r2', 'Druga rally');
      final cubit = ActiveRallyCubit(repo);
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as ActiveRallyLoaded;
      expect(state.rallies.map((r) => r.id), ['r2', 'r1']);
      expect(state.active?.id, 'r2');

      await cubit.close();
    });

    test('select promotes a rally to active and reloads', () async {
      await MyRalliesStore.recordVisit('r1');
      await MyRalliesStore.recordVisit('r2');

      final repo = _FakeRallyRepository()
        ..summaries['r1'] = _summary('r1', 'Prva rally')
        ..summaries['r2'] = _summary('r2', 'Druga rally');
      final cubit = ActiveRallyCubit(repo);
      await Future<void>.delayed(Duration.zero);

      await cubit.select('r1');

      final state = cubit.state as ActiveRallyLoaded;
      expect(state.active?.id, 'r1');
      expect(await MyRalliesStore.rallyIds(), ['r1', 'r2']);

      await cubit.close();
    });
  });
}
