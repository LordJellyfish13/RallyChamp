import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rallychamp/features/rallies/data/rally_repository.dart';
import 'package:rallychamp/features/rallies/data/rally_summary.dart';
import 'package:rallychamp/features/status/bloc/rally_status_cubit.dart';
import 'package:rallychamp/features/status/bloc/rally_status_state.dart';

class _FakeRallyRepository extends Fake implements RallyRepository {
  final _controller = StreamController<RallySummary?>();
  Map<String, Object?>? lastUpdate;

  @override
  Stream<RallySummary?> watchRallySummary(String rallyId) => _controller.stream;

  @override
  Future<String> updateRallyStatus({
    required String rallyId,
    required String status,
    DateTime? estimatedEndAt,
  }) async {
    lastUpdate = {
      'rallyId': rallyId,
      'status': status,
      'estimatedEndAt': estimatedEndAt,
    };
    return 'event-1';
  }

  void emit(RallySummary? rally) => _controller.add(rally);
  void dispose() => _controller.close();
}

RallySummary _rally({String status = 'setup'}) {
  return RallySummary(
    id: 'rally-1',
    name: 'Test rally',
    description: '',
    visibility: 'published',
    status: status,
    createdAt: DateTime(2026, 1, 1),
    adminUids: const ['admin-1'],
  );
}

void main() {
  group('RallyStatusCubit', () {
    test('starts loading', () async {
      final repo = _FakeRallyRepository();
      final cubit = RallyStatusCubit(repo, 'rally-1');

      expect(cubit.state, isA<RallyStatusLoading>());

      await cubit.close();
      repo.dispose();
    });

    test('emits Loaded when the live stream emits', () async {
      final repo = _FakeRallyRepository();
      final cubit = RallyStatusCubit(repo, 'rally-1');

      repo.emit(_rally(status: 'running'));
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as RallyStatusLoaded;
      expect(state.rally?.status, 'running');

      await cubit.close();
      repo.dispose();
    });

    test('updateStatus delegates to the repository', () async {
      final repo = _FakeRallyRepository();
      final cubit = RallyStatusCubit(repo, 'rally-1');

      await cubit.updateStatus('running');

      expect(repo.lastUpdate?['rallyId'], 'rally-1');
      expect(repo.lastUpdate?['status'], 'running');

      await cubit.close();
      repo.dispose();
    });

    test('updateStatus passes an expected-return time through', () async {
      final repo = _FakeRallyRepository();
      final cubit = RallyStatusCubit(repo, 'rally-1');
      final back = DateTime(2026, 9, 12, 12, 10);

      await cubit.updateStatus('paused', estimatedEndAt: back);

      expect(repo.lastUpdate?['status'], 'paused');
      expect(repo.lastUpdate?['estimatedEndAt'], back);

      await cubit.close();
      repo.dispose();
    });
  });
}
