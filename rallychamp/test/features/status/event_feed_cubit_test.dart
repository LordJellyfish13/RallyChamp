import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rallychamp/features/rallies/data/rally_event.dart';
import 'package:rallychamp/features/rallies/data/rally_repository.dart';
import 'package:rallychamp/features/status/bloc/event_feed_cubit.dart';
import 'package:rallychamp/features/status/bloc/event_feed_state.dart';

class _FakeRallyRepository extends Fake implements RallyRepository {
  final _controller = StreamController<List<RallyEvent>>();
  int? lastLimit;
  String? lastRetractedId;

  @override
  Stream<List<RallyEvent>> watchEvents(String rallyId, {int limit = 50}) {
    lastLimit = limit;
    return _controller.stream;
  }

  @override
  Future<void> retractEvent({
    required String rallyId,
    required String eventId,
  }) async {
    lastRetractedId = eventId;
  }

  void emit(List<RallyEvent> events) => _controller.add(events);
  void dispose() => _controller.close();
}

void main() {
  group('EventFeedCubit', () {
    test('starts loading', () async {
      final repo = _FakeRallyRepository();
      final cubit = EventFeedCubit(repo, 'rally-1');

      expect(cubit.state, isA<EventFeedLoading>());

      await cubit.close();
      repo.dispose();
    });

    test('emits Loaded when the feed emits', () async {
      final repo = _FakeRallyRepository();
      final cubit = EventFeedCubit(repo, 'rally-1');

      repo.emit([
        syntheticStatusEvent('running', DateTime(2026, 9, 12, 9, 5)),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect((cubit.state as EventFeedLoaded).events, hasLength(1));

      await cubit.close();
      repo.dispose();
    });

    test('retract delegates to the repository', () async {
      final repo = _FakeRallyRepository();
      final cubit = EventFeedCubit(repo, 'rally-1');

      await cubit.retract('event-7');

      expect(repo.lastRetractedId, 'event-7');

      await cubit.close();
      repo.dispose();
    });

    test('an empty log is a normal Loaded state, not an error', () async {
      final repo = _FakeRallyRepository();
      final cubit = EventFeedCubit(repo, 'rally-1');

      repo.emit([]);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<EventFeedLoaded>());
      expect((cubit.state as EventFeedLoaded).events, isEmpty);

      await cubit.close();
      repo.dispose();
    });
  });
}
