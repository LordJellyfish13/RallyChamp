import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/rally_repository.dart';
import 'create_rally_state.dart';

class CreateRallyCubit extends Cubit<CreateRallyState> {
  CreateRallyCubit(this._repository) : super(const CreateRallyIdle());

  final RallyRepository _repository;

  Future<void> submit({
    required String name,
    required String description,
    required String locationName,
    required DateTime startDate,
    required DateTime endDate,
    required int stageCount,
    required bool publishImmediately,
    bool allowWalkupMarshals = true,
  }) async {
    emit(const CreateRallySubmitting());
    try {
      final rallyId = await _repository.createRally(
        name: name,
        description: description,
        locationName: locationName,
        startDate: startDate,
        endDate: endDate,
        stageCount: stageCount,
        publishImmediately: publishImmediately,
        allowWalkupMarshals: allowWalkupMarshals,
      );
      emit(CreateRallySuccess(rallyId));
    } catch (e) {
      emit(CreateRallyFailure('$e'));
    }
  }
}
