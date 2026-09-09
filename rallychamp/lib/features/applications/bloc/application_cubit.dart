import 'package:firebase_auth/firebase_auth.dart';
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
    required String email,
    String? password,
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
        email: email,
        password: password,
        phone: phone,
        oib: oib,
        licenseNumber: licenseNumber,
      );
      emit(const ApplicationSuccess());
    } on FirebaseAuthException catch (e) {
      emit(ApplicationFailure(_mapAuthError(e)));
    } catch (e) {
      emit(ApplicationFailure('$e'));
    }
  }

  Future<void> submitTeam({
    required String rallyId,
    required String teamName,
    required String driverName,
    required String carNumber,
    required String carClass,
    required String email,
    String? password,
    required String phone,
    required String oib,
  }) async {
    emit(const ApplicationSubmitting());
    try {
      await _repository.submitTeamEntry(
        rallyId: rallyId,
        teamName: teamName,
        driverName: driverName,
        carNumber: carNumber,
        carClass: carClass,
        email: email,
        password: password,
        phone: phone,
        oib: oib,
      );
      emit(const ApplicationSuccess());
    } on FirebaseAuthException catch (e) {
      emit(ApplicationFailure(_mapAuthError(e)));
    } catch (e) {
      emit(ApplicationFailure('$e'));
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak (use at least 6 characters).';
      case 'invalid-email':
        return 'That email address looks invalid.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
