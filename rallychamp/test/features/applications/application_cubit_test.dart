import 'package:flutter_test/flutter_test.dart';
import 'package:rallychamp/features/applications/bloc/application_cubit.dart';
import 'package:rallychamp/features/applications/bloc/application_state.dart';
import 'package:rallychamp/features/applications/data/applications_repository.dart';
import 'package:rallychamp/features/applications/data/staff_application_summary.dart';
import 'package:rallychamp/features/applications/data/staff_role.dart';

class _FakeApplicationsRepository implements ApplicationsRepository {
  bool shouldThrow = false;
  Map<String, Object?>? lastSubmission;

  @override
  Future<void> submitStaffApplication({
    required String rallyId,
    required StaffRole role,
    required String name,
    required String phone,
    required String oib,
    String? licenseNumber,
  }) async {
    if (shouldThrow) {
      throw Exception('permission-denied');
    }
    lastSubmission = {'rallyId': rallyId, 'role': role, 'name': name};
  }

  @override
  Future<void> submitTeamEntry({
    required String rallyId,
    required String teamName,
    required String driverName,
    required String coDriverName,
    required String carNumber,
    required String carClass,
    required String phone,
    required String oib,
  }) async {
    if (shouldThrow) {
      throw Exception('permission-denied');
    }
    lastSubmission = {'rallyId': rallyId, 'teamName': teamName};
  }

  @override
  Stream<List<StaffApplicationSummary>> watchStaffApplications(
    String rallyId,
  ) => const Stream.empty();

  @override
  Future<void> reviewStaffApplication({
    required String rallyId,
    required String uid,
    required bool accept,
    String? assignedCheckpointId,
  }) async {}
}

void main() {
  group('ApplicationCubit.submitStaff', () {
    test('starts idle', () async {
      final cubit = ApplicationCubit(_FakeApplicationsRepository());
      expect(cubit.state, isA<ApplicationIdle>());
      await cubit.close();
    });

    test('ends in Success and delegates to the repository', () async {
      final repo = _FakeApplicationsRepository();
      final cubit = ApplicationCubit(repo);

      final future = cubit.submitStaff(
        rallyId: 'rally-1',
        role: StaffRole.marshal,
        name: 'Ana',
        phone: '0911234567',
        oib: '12345678901',
      );
      expect(cubit.state, isA<ApplicationSubmitting>());

      await future;

      expect(cubit.state, isA<ApplicationSuccess>());
      expect(repo.lastSubmission?['rallyId'], 'rally-1');
      expect(repo.lastSubmission?['role'], StaffRole.marshal);

      await cubit.close();
    });

    test('emits Failure when the repository throws', () async {
      final repo = _FakeApplicationsRepository()..shouldThrow = true;
      final cubit = ApplicationCubit(repo);

      await cubit.submitStaff(
        rallyId: 'rally-1',
        role: StaffRole.judge,
        name: 'Ana',
        phone: '0911234567',
        oib: '12345678901',
        licenseNumber: 'J-123',
      );

      expect(cubit.state, isA<ApplicationFailure>());

      await cubit.close();
    });
  });

  group('ApplicationCubit.submitTeam', () {
    test('ends in Success and delegates to the repository', () async {
      final repo = _FakeApplicationsRepository();
      final cubit = ApplicationCubit(repo);

      final future = cubit.submitTeam(
        rallyId: 'rally-1',
        teamName: 'Team Šuma',
        driverName: 'Ana',
        coDriverName: 'Iva',
        carNumber: '7',
        carClass: 'N4',
        phone: '0911234567',
        oib: '12345678901',
      );
      expect(cubit.state, isA<ApplicationSubmitting>());

      await future;

      expect(cubit.state, isA<ApplicationSuccess>());
      expect(repo.lastSubmission?['teamName'], 'Team Šuma');

      await cubit.close();
    });

    test('emits Failure when the repository throws', () async {
      final repo = _FakeApplicationsRepository()..shouldThrow = true;
      final cubit = ApplicationCubit(repo);

      await cubit.submitTeam(
        rallyId: 'rally-1',
        teamName: 'Team Šuma',
        driverName: 'Ana',
        coDriverName: 'Iva',
        carNumber: '7',
        carClass: 'N4',
        phone: '0911234567',
        oib: '12345678901',
      );

      expect(cubit.state, isA<ApplicationFailure>());

      await cubit.close();
    });
  });
}
