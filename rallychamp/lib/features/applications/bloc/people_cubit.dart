import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../rallies/data/checkpoint.dart';
import '../../rallies/data/rally_repository.dart';
import '../data/applications_repository.dart';
import '../data/staff_application_summary.dart';
import 'people_state.dart';

/// Combines two independent live streams — accepted staff and checkpoints —
/// for the People roster. Deliberately re-derives `PeopleLoaded` from
/// whatever's currently known each time either stream updates, rather than
/// computing a default from just the first snapshot to arrive: see
/// dev_notes.md §5 "Per-stage route filter + Start/Finish markers" for the
/// bug that exact shortcut caused elsewhere when two independent streams
/// raced.
class PeopleCubit extends Cubit<PeopleState> {
  PeopleCubit(this._applicationsRepository, this._rallyRepository, this.rallyId)
    : super(const PeopleLoading()) {
    _staffSubscription = _applicationsRepository.watchAcceptedStaff(rallyId).listen(
      (staff) {
        _staff = staff;
        _emitLoaded();
      },
      onError: (Object error, StackTrace _) {
        if (!isClosed) emit(PeopleError('$error'));
      },
    );
    _checkpointsSubscription = _rallyRepository.watchCheckpoints(rallyId).listen((
      checkpoints,
    ) {
      _checkpoints = checkpoints;
      _emitLoaded();
    });
  }

  final ApplicationsRepository _applicationsRepository;
  final RallyRepository _rallyRepository;
  final String rallyId;

  late final StreamSubscription<List<StaffApplicationSummary>>
  _staffSubscription;
  late final StreamSubscription<List<Checkpoint>> _checkpointsSubscription;

  List<StaffApplicationSummary>? _staff;
  List<Checkpoint> _checkpoints = const [];

  void _emitLoaded() {
    final staff = _staff;
    if (staff == null || isClosed) return;
    emit(PeopleLoaded(staff: staff, checkpoints: _checkpoints));
  }

  @override
  Future<void> close() {
    _staffSubscription.cancel();
    _checkpointsSubscription.cancel();
    return super.close();
  }
}
