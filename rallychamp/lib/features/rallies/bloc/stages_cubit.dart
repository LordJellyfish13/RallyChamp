import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../data/rally_repository.dart';
import '../data/stage.dart';
import 'stages_state.dart';

class StagesCubit extends Cubit<StagesState> {
  StagesCubit(this._repository, this.rallyId) : super(const StagesLoading()) {
    _subscription = _repository.watchStages(rallyId).listen(
      (stages) => emit(StagesLoaded(stages)),
      onError: (Object error, StackTrace _) => emit(StagesError('$error')),
    );
  }

  final RallyRepository _repository;
  final String rallyId;
  late final StreamSubscription<List<Stage>> _subscription;

  Future<void> saveRoute({
    required String stageId,
    required List<LatLng> route,
  }) {
    return _repository.updateStageRoute(
      rallyId: rallyId,
      stageId: stageId,
      route: route,
    );
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
