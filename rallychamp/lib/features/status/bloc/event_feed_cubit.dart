import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../rallies/data/rally_event.dart';
import '../../rallies/data/rally_repository.dart';
import 'event_feed_state.dart';

/// The Status page's activity log. A plain live subscription — unlike
/// `RallyStatusCubit` it has no write side, since events are only ever
/// written as a side effect of the thing that caused them (a status
/// change today, an incident report in v2), never on their own.
class EventFeedCubit extends Cubit<EventFeedState> {
  EventFeedCubit(this._repository, this.rallyId)
    : super(const EventFeedLoading()) {
    _subscription = _repository.watchEvents(rallyId).listen(
      (events) => emit(EventFeedLoaded(events)),
      onError: (Object error, StackTrace _) {
        if (!isClosed) emit(EventFeedError('$error'));
      },
    );
  }

  final RallyRepository _repository;
  final String rallyId;
  late final StreamSubscription<List<RallyEvent>> _subscription;

  /// Withdraws an entry logged by mistake. No local state to update — the
  /// live feed reflects the write back on its own.
  Future<void> retract(String eventId) {
    return _repository.retractEvent(rallyId: rallyId, eventId: eventId);
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
