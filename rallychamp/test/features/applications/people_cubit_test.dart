import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rallychamp/features/applications/bloc/people_cubit.dart';
import 'package:rallychamp/features/applications/bloc/people_state.dart';
import 'package:rallychamp/features/applications/data/applications_repository.dart';
import 'package:rallychamp/features/applications/data/staff_application_summary.dart';
import 'package:rallychamp/features/applications/data/staff_role.dart';
import 'package:rallychamp/features/rallies/data/checkpoint.dart';
import 'package:rallychamp/features/rallies/data/rally_repository.dart';

class _FakeApplicationsRepository extends Fake implements ApplicationsRepository {
  final _staffController = StreamController<List<StaffApplicationSummary>>();

  @override
  Stream<List<StaffApplicationSummary>> watchAcceptedStaff(String rallyId) =>
      _staffController.stream;

  void emitStaff(List<StaffApplicationSummary> staff) =>
      _staffController.add(staff);
  void dispose() => _staffController.close();

}

class _FakeRallyRepository extends Fake implements RallyRepository {
  final _checkpointsController = StreamController<List<Checkpoint>>();

  @override
  Stream<List<Checkpoint>> watchCheckpoints(String rallyId) =>
      _checkpointsController.stream;

  void emitCheckpoints(List<Checkpoint> checkpoints) =>
      _checkpointsController.add(checkpoints);
  void dispose() => _checkpointsController.close();
}

StaffApplicationSummary _staff({
  String uid = 'u1',
  String? assignedCheckpointId,
}) {
  return StaffApplicationSummary(
    uid: uid,
    role: StaffRole.marshal,
    status: 'accepted',
    applicantName: 'Ana',
    applicantPhone: '0911234567',
    assignedCheckpointId: assignedCheckpointId,
    appliedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('PeopleCubit', () {
    test('starts loading', () async {
      final applicationsRepo = _FakeApplicationsRepository();
      final rallyRepo = _FakeRallyRepository();
      final cubit = PeopleCubit(applicationsRepo, rallyRepo, 'rally-1');

      expect(cubit.state, isA<PeopleLoading>());

      await cubit.close();
      applicationsRepo.dispose();
      rallyRepo.dispose();
    });

    test('emits Loaded once the accepted-staff stream emits, even before '
        'checkpoints arrive', () async {
      final applicationsRepo = _FakeApplicationsRepository();
      final rallyRepo = _FakeRallyRepository();
      final cubit = PeopleCubit(applicationsRepo, rallyRepo, 'rally-1');

      applicationsRepo.emitStaff([_staff()]);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<PeopleLoaded>());
      final loaded = cubit.state as PeopleLoaded;
      expect(loaded.staff, hasLength(1));
      expect(loaded.checkpoints, isEmpty);

      await cubit.close();
      applicationsRepo.dispose();
      rallyRepo.dispose();
    });

    test('re-emits with checkpoints once that stream catches up', () async {
      final applicationsRepo = _FakeApplicationsRepository();
      final rallyRepo = _FakeRallyRepository();
      final cubit = PeopleCubit(applicationsRepo, rallyRepo, 'rally-1');

      applicationsRepo.emitStaff([_staff(assignedCheckpointId: 'cp-1')]);
      await Future<void>.delayed(Duration.zero);

      rallyRepo.emitCheckpoints([
        const Checkpoint(id: 'cp-1', code: 'R13', kind: CheckpointKind.viewing),
      ]);
      await Future<void>.delayed(Duration.zero);

      final loaded = cubit.state as PeopleLoaded;
      expect(loaded.checkpoints, hasLength(1));
      expect(loaded.checkpoints.first.code, 'R13');

      await cubit.close();
      applicationsRepo.dispose();
      rallyRepo.dispose();
    });
  });
}
