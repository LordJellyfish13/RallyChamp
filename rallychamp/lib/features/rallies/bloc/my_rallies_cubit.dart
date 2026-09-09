import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/rally_repository.dart';
import '../data/rally_summary.dart';
import 'my_rallies_state.dart';

class MyRalliesCubit extends Cubit<MyRalliesState> {
  MyRalliesCubit(this._repository) : super(const MyRalliesLoading()) {
    _subscription = _repository.watchMyRallies().listen(
      (rallies) => emit(MyRalliesLoaded(rallies)),
      onError: (Object error, StackTrace _) => emit(MyRalliesError('$error')),
    );
  }

  final RallyRepository _repository;
  late final StreamSubscription<List<RallySummary>> _subscription;

  Future<void> publishRally(RallySummary rally) {
    return _repository.publishRally(
      rallyId: rally.id,
      name: rally.name,
      description: rally.description,
    );
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
