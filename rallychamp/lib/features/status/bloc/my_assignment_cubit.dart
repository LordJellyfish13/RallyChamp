import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../applications/data/applications_repository.dart';
import '../../applications/data/staff_application_summary.dart';
import '../../rallies/data/rally_repository.dart';
import 'my_assignment_state.dart';

/// Resolves the signed-in user's own staff application (if any) plus its
/// assigned checkpoint, for the Status page's on-duty banner. Kept separate
/// from `ActiveRallyCubit` since it's a different, per-rally-id question
/// ("am I working this specific rally") rather than "which rally is
/// active" — see dev_notes.md §5 "People screen + on-duty assignment
/// banner".
class MyAssignmentCubit extends Cubit<MyAssignmentState> {
  MyAssignmentCubit(
    this._applicationsRepository,
    this._rallyRepository,
    this.rallyId,
  ) : super(const MyAssignmentLoading()) {
    _subscription = _applicationsRepository
        .watchMyStaffApplication(rallyId)
        .listen(
          _onApplication,
          onError: (Object error, StackTrace _) {
            if (!isClosed) emit(MyAssignmentError('$error'));
          },
        );
  }

  final ApplicationsRepository _applicationsRepository;
  final RallyRepository _rallyRepository;
  final String rallyId;
  late final StreamSubscription<StaffApplicationSummary?> _subscription;

  Future<void> _onApplication(StaffApplicationSummary? application) async {
    if (application == null || application.status != 'accepted') {
      if (!isClosed) emit(const MyAssignmentLoaded());
      return;
    }
    final checkpointId = application.assignedCheckpointId;
    final checkpoint = checkpointId == null
        ? null
        : await _rallyRepository.getCheckpoint(rallyId, checkpointId);
    if (!isClosed) {
      emit(MyAssignmentLoaded(application: application, checkpoint: checkpoint));
    }
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
