import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/checkpoint.dart';
import '../data/rally_repository.dart';
import 'checkpoints_state.dart';

class CheckpointsCubit extends Cubit<CheckpointsState> {
  CheckpointsCubit(this._repository, this.rallyId)
    : super(const CheckpointsLoading()) {
    _subscription = _repository.watchCheckpoints(rallyId).listen(
      (checkpoints) => emit(CheckpointsLoaded(checkpoints)),
      onError: (Object error, StackTrace _) => emit(CheckpointsError('$error')),
    );
  }

  final RallyRepository _repository;
  final String rallyId;
  late final StreamSubscription<List<Checkpoint>> _subscription;

  Future<void> addCheckpoint({
    required String code,
    required CheckpointKind kind,
    String? stageId,
    GeoPoint? location,
  }) {
    return _repository.createCheckpoint(
      rallyId: rallyId,
      code: code,
      kind: kind,
      stageId: stageId,
      location: location,
    );
  }

  Future<void> updateCheckpoint({
    required String checkpointId,
    required String code,
    required CheckpointKind kind,
    String? stageId,
    GeoPoint? location,
  }) {
    return _repository.updateCheckpoint(
      rallyId: rallyId,
      checkpointId: checkpointId,
      code: code,
      kind: kind,
      stageId: stageId,
      location: location,
    );
  }

  Future<void> deleteCheckpoint(String checkpointId) {
    return _repository.deleteCheckpoint(
      rallyId: rallyId,
      checkpointId: checkpointId,
    );
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
