import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rallychamp/features/applications/data/applications_repository.dart';
import 'package:rallychamp/features/applications/data/staff_application_summary.dart';
import 'package:rallychamp/features/applications/data/staff_role.dart';
import 'package:rallychamp/features/rallies/data/checkpoint.dart';
import 'package:rallychamp/features/rallies/data/rally_repository.dart';
import 'package:rallychamp/features/status/bloc/my_assignment_cubit.dart';
import 'package:rallychamp/features/status/bloc/my_assignment_state.dart';

class _FakeApplicationsRepository extends Fake implements ApplicationsRepository {
  final _myApplicationController = StreamController<StaffApplicationSummary?>();

  @override
  Stream<StaffApplicationSummary?> watchMyStaffApplication(String rallyId) =>
      _myApplicationController.stream;

  void emitMyApplication(StaffApplicationSummary? application) =>
      _myApplicationController.add(application);
  void dispose() => _myApplicationController.close();

}

class _FakeRallyRepository extends Fake implements RallyRepository {
  final Map<String, Checkpoint> checkpoints = {};

  @override
  Future<Checkpoint?> getCheckpoint(String rallyId, String checkpointId) async =>
      checkpoints[checkpointId];

}

StaffApplicationSummary _staff({
  String status = 'accepted',
  String? assignedCheckpointId,
}) {
  return StaffApplicationSummary(
    uid: 'u1',
    role: StaffRole.marshal,
    status: status,
    applicantName: 'Ana',
    applicantPhone: '0911234567',
    assignedCheckpointId: assignedCheckpointId,
    appliedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('MyAssignmentCubit', () {
    test('starts loading', () async {
      final applicationsRepo = _FakeApplicationsRepository();
      final rallyRepo = _FakeRallyRepository();
      final cubit = MyAssignmentCubit(applicationsRepo, rallyRepo, 'rally-1');

      expect(cubit.state, isA<MyAssignmentLoading>());

      await cubit.close();
      applicationsRepo.dispose();
    });

    test('emits an empty Loaded when there is no application', () async {
      final applicationsRepo = _FakeApplicationsRepository();
      final rallyRepo = _FakeRallyRepository();
      final cubit = MyAssignmentCubit(applicationsRepo, rallyRepo, 'rally-1');

      applicationsRepo.emitMyApplication(null);
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as MyAssignmentLoaded;
      expect(state.application, isNull);
      expect(state.checkpoint, isNull);

      await cubit.close();
      applicationsRepo.dispose();
    });

    test('emits an empty Loaded when the application is only pending', () async {
      final applicationsRepo = _FakeApplicationsRepository();
      final rallyRepo = _FakeRallyRepository();
      final cubit = MyAssignmentCubit(applicationsRepo, rallyRepo, 'rally-1');

      applicationsRepo.emitMyApplication(_staff(status: 'pending'));
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as MyAssignmentLoaded;
      expect(state.application, isNull);

      await cubit.close();
      applicationsRepo.dispose();
    });

    test('resolves the assigned checkpoint for an accepted application', () async {
      final applicationsRepo = _FakeApplicationsRepository();
      final rallyRepo = _FakeRallyRepository()
        ..checkpoints['cp-1'] = const Checkpoint(
          id: 'cp-1',
          code: 'R13',
          kind: CheckpointKind.viewing,
        );
      final cubit = MyAssignmentCubit(applicationsRepo, rallyRepo, 'rally-1');

      applicationsRepo.emitMyApplication(
        _staff(assignedCheckpointId: 'cp-1'),
      );
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as MyAssignmentLoaded;
      expect(state.application, isNotNull);
      expect(state.checkpoint?.code, 'R13');

      await cubit.close();
      applicationsRepo.dispose();
    });

    test('accepted but unassigned resolves to a null checkpoint', () async {
      final applicationsRepo = _FakeApplicationsRepository();
      final rallyRepo = _FakeRallyRepository();
      final cubit = MyAssignmentCubit(applicationsRepo, rallyRepo, 'rally-1');

      applicationsRepo.emitMyApplication(_staff());
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as MyAssignmentLoaded;
      expect(state.application, isNotNull);
      expect(state.checkpoint, isNull);

      await cubit.close();
      applicationsRepo.dispose();
    });
  });
}
