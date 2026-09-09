import 'package:flutter_test/flutter_test.dart';
import 'package:rallychamp/features/rallies/bloc/create_rally_cubit.dart';
import 'package:rallychamp/features/rallies/bloc/create_rally_state.dart';
import 'package:rallychamp/features/rallies/data/rally_repository.dart';
import 'package:rallychamp/features/rallies/data/rally_summary.dart';

class _FakeRallyRepository implements RallyRepository {
  bool shouldThrow = false;
  Map<String, Object?>? lastCreate;

  @override
  Future<String> createRally({
    required String name,
    required String description,
    required String locationName,
    required DateTime startDate,
    required DateTime endDate,
    required int stageCount,
    required bool publishImmediately,
  }) async {
    if (shouldThrow) {
      throw Exception('permission-denied');
    }
    lastCreate = {
      'name': name,
      'stageCount': stageCount,
      'publishImmediately': publishImmediately,
    };
    return 'rally-123';
  }

  @override
  Stream<List<RallySummary>> watchMyRallies() => const Stream.empty();

  @override
  Future<void> publishRally({
    required String rallyId,
    required String name,
    required String description,
  }) async {}
}

void main() {
  group('CreateRallyCubit', () {
    test('starts idle', () async {
      final cubit = CreateRallyCubit(_FakeRallyRepository());
      expect(cubit.state, isA<CreateRallyIdle>());
      await cubit.close();
    });

    test('ends in Success with the new rally id', () async {
      final repo = _FakeRallyRepository();
      final cubit = CreateRallyCubit(repo);

      final future = cubit.submit(
        name: 'Šumska Rally',
        description: 'A fun one',
        locationName: 'Risnjak',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 2),
        stageCount: 3,
        publishImmediately: true,
      );
      expect(cubit.state, isA<CreateRallySubmitting>());

      await future;

      expect(cubit.state, isA<CreateRallySuccess>());
      expect((cubit.state as CreateRallySuccess).rallyId, 'rally-123');
      expect(repo.lastCreate?['stageCount'], 3);
      expect(repo.lastCreate?['publishImmediately'], true);

      await cubit.close();
    });

    test('emits Failure when the repository throws', () async {
      final repo = _FakeRallyRepository()..shouldThrow = true;
      final cubit = CreateRallyCubit(repo);

      await cubit.submit(
        name: 'Šumska Rally',
        description: 'A fun one',
        locationName: 'Risnjak',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 2),
        stageCount: 1,
        publishImmediately: false,
      );

      expect(cubit.state, isA<CreateRallyFailure>());

      await cubit.close();
    });
  });
}
