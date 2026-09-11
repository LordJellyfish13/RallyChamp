import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/applications_repository.dart';
import '../data/staff_application_summary.dart';
import 'applications_review_state.dart';

class ApplicationsReviewCubit extends Cubit<ApplicationsReviewState> {
  ApplicationsReviewCubit(this._repository, this.rallyId)
    : super(const ApplicationsReviewLoading()) {
    _subscription = _repository.watchStaffApplications(rallyId).listen(
      (applications) => emit(ApplicationsReviewLoaded(applications)),
      onError: (Object error, StackTrace _) =>
          emit(ApplicationsReviewError('$error')),
    );
  }

  final ApplicationsRepository _repository;
  final String rallyId;
  late final StreamSubscription<List<StaffApplicationSummary>> _subscription;

  Future<void> review({
    required String uid,
    required bool accept,
    String? assignedCheckpointId,
  }) {
    return _repository.reviewStaffApplication(
      rallyId: rallyId,
      uid: uid,
      accept: accept,
      assignedCheckpointId: assignedCheckpointId,
    );
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
