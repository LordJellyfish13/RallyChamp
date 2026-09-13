import 'package:equatable/equatable.dart';

import '../../rallies/data/rally_event.dart';

sealed class EventFeedState extends Equatable {
  const EventFeedState();

  @override
  List<Object?> get props => [];
}

class EventFeedLoading extends EventFeedState {
  const EventFeedLoading();
}

/// [events] is newest-first. Empty is a perfectly normal state, not an
/// error: rallies created before the activity log existed have no events
/// at all, which is why the Status page falls back to the rally's current
/// `status` for its hero card rather than depending on this list.
class EventFeedLoaded extends EventFeedState {
  const EventFeedLoaded(this.events);

  final List<RallyEvent> events;

  @override
  List<Object?> get props => [events];
}

class EventFeedError extends EventFeedState {
  const EventFeedError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
