import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/notifications/push_sender.dart';
import '../../rallies/data/rally_repository.dart';
import '../../rallies/data/rally_summary.dart';
import 'rally_status_state.dart';

/// Live status for one rally — subscribes to `watchRallySummary` (a
/// `snapshots()` stream) rather than the one-shot `getRallySummary` that
/// `ActiveRallyCubit` uses, so a status change made by the organizer
/// reaches everyone with the Status page open within moments, not just on
/// their next visit to the tab. Also carries `updateStatus` for the
/// organizer's own status control, so the write and the live read that
/// reflects it back both go through the same cubit.
class RallyStatusCubit extends Cubit<RallyStatusState> {
  RallyStatusCubit(this._repository, this.rallyId)
    : super(const RallyStatusLoading()) {
    _subscription = _repository.watchRallySummary(rallyId).listen(
      (rally) => emit(RallyStatusLoaded(rally)),
      onError: (Object error, StackTrace _) {
        if (!isClosed) emit(RallyStatusError('$error'));
      },
    );
  }

  final RallyRepository _repository;
  final String rallyId;
  late final StreamSubscription<RallySummary?> _subscription;

  Future<void> updateStatus(String status, {DateTime? estimatedEndAt}) async {
    final eventId = await _repository.updateRallyStatus(
      rallyId: rallyId,
      status: status,
      estimatedEndAt: estimatedEndAt,
    );
    // Explicit rather than buried in the repository: this puts a
    // notification on strangers' phones, so the decision to do it should
    // be visible at the call site. It never throws and never blocks the
    // status change — the endpoint independently decides whether the
    // event is worth pushing at all.
    await requestPush(rallyId: rallyId, eventId: eventId);
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
