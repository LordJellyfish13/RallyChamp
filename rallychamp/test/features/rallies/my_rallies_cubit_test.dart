import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rallychamp/features/rallies/bloc/my_rallies_cubit.dart';
import 'package:rallychamp/features/rallies/bloc/my_rallies_state.dart';
import 'package:rallychamp/features/rallies/data/rally_repository.dart';
import 'package:rallychamp/features/rallies/data/rally_summary.dart';

class _FakeRallyRepository implements RallyRepository {
  final _controller = StreamController<List<RallySummary>>();
  String? lastPublishedId;

  @override
  Future<String> createRally({
    required String name,
    required String description,
    required String locationName,
    required DateTime startDate,
    required DateTime endDate,
    required int stageCount,
    required bool publishImmediately,
  }) async => 'unused';

  @override
  Stream<List<RallySummary>> watchMyRallies() => _controller.stream;

  @override
  Future<void> publishRally({
    required String rallyId,
    required String name,
    required String description,
  }) async {
    lastPublishedId = rallyId;
  }

  void emit(List<RallySummary> rallies) => _controller.add(rallies);
  void dispose() => _controller.close();
}

RallySummary _summary({String id = 'r1', bool draft = true}) {
  return RallySummary(
    id: id,
    name: 'Šumska Rally',
    description: 'A fun one',
    visibility: draft ? 'draft' : 'published',
    status: 'setup',
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('MyRalliesCubit', () {
    test('starts loading', () async {
      final repo = _FakeRallyRepository();
      final cubit = MyRalliesCubit(repo);
      expect(cubit.state, isA<MyRalliesLoading>());
      await cubit.close();
      repo.dispose();
    });

    test('emits MyRalliesLoaded when the repository stream emits', () async {
      final repo = _FakeRallyRepository();
      final cubit = MyRalliesCubit(repo);

      repo.emit([_summary()]);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<MyRalliesLoaded>());
      expect((cubit.state as MyRalliesLoaded).rallies, hasLength(1));

      await cubit.close();
      repo.dispose();
    });

    test('publishRally delegates to the repository', () async {
      final repo = _FakeRallyRepository();
      final cubit = MyRalliesCubit(repo);

      await cubit.publishRally(_summary(id: 'r42'));

      expect(repo.lastPublishedId, 'r42');

      await cubit.close();
      repo.dispose();
    });
  });
}
