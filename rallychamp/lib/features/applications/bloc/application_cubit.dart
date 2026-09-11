import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/applications_repository.dart';
import '../data/staff_role.dart';
import 'application_state.dart';

class ApplicationCubit extends Cubit<ApplicationState> {
  ApplicationCubit(this._repository) : super(const ApplicationIdle());

  final ApplicationsRepository _repository;

  Future<void> submitStaff({
    required String rallyId,
    required StaffRole role,
    required String name,
    required String phone,
    required String oib,
    String? licenseNumber,
  }) async {
    emit(const ApplicationSubmitting());
    try {
      await _repository.submitStaffApplication(
        rallyId: rallyId,
        role: role,
        name: name,
        phone: phone,
        oib: oib,
        licenseNumber: licenseNumber,
      );
      emit(const ApplicationSuccess());
    } catch (e) {
      emit(ApplicationFailure('$e'));
    }
  }

  Future<void> submitTeam({
    required String rallyId,
    required String teamName,
    required String driverName,
    required String coDriverName,
    required String carNumber,
    required String carClass,
    required String phone,
    required String oib,
  }) async {
    emit(const ApplicationSubmitting());
    try {
      await _repository.submitTeamEntry(
        rallyId: rallyId,
        teamName: teamName,
        driverName: driverName,
        coDriverName: coDriverName,
        carNumber: carNumber,
        carClass: carClass,
        phone: phone,
        oib: oib,
      );
      emit(const ApplicationSuccess());
    } catch (e) {
      emit(ApplicationFailure('$e'));
    }
  }
}
