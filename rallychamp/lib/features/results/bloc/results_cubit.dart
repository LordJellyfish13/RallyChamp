import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/results_repository.dart';
import '../data/stage_result.dart';

sealed class ResultsState extends Equatable {
  const ResultsState();

  @override
  List<Object?> get props => [];
}

class ResultsLoading extends ResultsState {
  const ResultsLoading();
}

class ResultsLoaded extends ResultsState {
  const ResultsLoaded(this.results);

  final List<StageResult> results;

  List<StageResult> forStage(String stageId) =>
      results.where((result) => result.stageId == stageId).toList();

  StageResult? forEntryOnStage(String entryId, String stageId) {
    for (final result in results) {
      if (result.entryId == entryId && result.stageId == stageId) return result;
    }
    return null;
  }

  @override
  List<Object?> get props => [results];
}

class ResultsError extends ResultsState {
  const ResultsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class ResultsCubit extends Cubit<ResultsState> {
  ResultsCubit(this._repository, this.rallyId) : super(const ResultsLoading()) {
    _subscription = _repository.watchResults(rallyId).listen(
      (results) => emit(ResultsLoaded(results)),
      onError: (Object error, StackTrace _) {
        if (!isClosed) emit(ResultsError('$error'));
      },
    );
  }

  final ResultsRepository _repository;
  final String rallyId;
  late final StreamSubscription<List<StageResult>> _subscription;

  Future<void> save({
    required String stageId,
    required String entryId,
    required String carNumber,
    required ResultStatus status,
    int? timeMs,
  }) {
    return _repository.saveResult(
      rallyId: rallyId,
      stageId: stageId,
      entryId: entryId,
      carNumber: carNumber,
      status: status,
      timeMs: timeMs,
    );
  }

  Future<void> clear({required String stageId, required String entryId}) {
    return _repository.deleteResult(
      rallyId: rallyId,
      stageId: stageId,
      entryId: entryId,
    );
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
