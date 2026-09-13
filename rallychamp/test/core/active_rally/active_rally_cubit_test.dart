import 'package:flutter_test/flutter_test.dart';
import 'package:rallychamp/core/active_rally/active_rally_cubit.dart';
import 'package:rallychamp/core/active_rally/active_rally_state.dart';
import 'package:rallychamp/core/active_rally/my_rallies_store.dart';
import 'package:rallychamp/features/rallies/data/rally_repository.dart';
import 'package:rallychamp/features/rallies/data/rally_summary.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRallyRepository extends Fake implements RallyRepository {
  final Map<String, RallySummary> summaries = {};

  @override
  Future<RallySummary?> getRallySummary(String rallyId) async =>
      summaries[rallyId];

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
