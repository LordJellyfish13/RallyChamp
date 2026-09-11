import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rallychamp/features/applications/bloc/applications_review_cubit.dart';
import 'package:rallychamp/features/applications/bloc/applications_review_state.dart';
import 'package:rallychamp/features/applications/data/applications_repository.dart';
import 'package:rallychamp/features/applications/data/staff_application_summary.dart';
import 'package:rallychamp/features/applications/data/staff_role.dart';

class _FakeApplicationsRepository implements ApplicationsRepository {
  final _controller = StreamController<List<StaffApplicationSummary>>();
  Map<String, Object?>? lastReview;

  @override
  Stream<List<StaffApplicationSummary>> watchStaffApplications(
    String rallyId,
  ) => _controller.stream;

  @override
  Future<void> reviewStaffApplication({
    required String rallyId,
    required String uid,
    required bool accept,
    String? assignedCheckpointId,
  }) async {
    lastReview = {
      'rallyId': rallyId,
      'uid': uid,
      'accept': accept,
      'assignedCheckpointId': assignedCheckpointId,
    };
  }

  @override
  Future<void> submitStaffApplication({
    required String rallyId,
    required StaffRole role,
    required String name,
    required String phone,
    required String oib,
    String? licenseNumber,
  }) async {}

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
  }) async {}

  void emit(List<StaffApplicationSummary> applications) =>
      _controller.add(applications);
  void dispose() => _controller.close();
}

StaffApplicationSummary _summary({
  String uid = 'u1',
  String status = 'pending',
}) {
  return StaffApplicationSummary(
    uid: uid,
    role: StaffRole.marshal,
    status: status,
    applicantName: 'Ana',
    applicantPhone: '0911234567',
    assignedCheckpointId: null,
    appliedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('ApplicationsReviewCubit', () {
    test('starts loading', () async {
      final repo = _FakeApplicationsRepository();
      final cubit = ApplicationsReviewCubit(repo, 'rally-1');
      expect(cubit.state, isA<ApplicationsReviewLoading>());
      await cubit.close();
      repo.dispose();
    });

    test('emits ApplicationsReviewLoaded when the stream emits', () async {
      final repo = _FakeApplicationsRepository();
      final cubit = ApplicationsReviewCubit(repo, 'rally-1');

      repo.emit([_summary()]);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<ApplicationsReviewLoaded>());
      expect(
        (cubit.state as ApplicationsReviewLoaded).applications,
        hasLength(1),
      );

      await cubit.close();
      repo.dispose();
    });

    test('review delegates to the repository', () async {
      final repo = _FakeApplicationsRepository();
      final cubit = ApplicationsReviewCubit(repo, 'rally-1');

      await cubit.review(
        uid: 'u1',
        accept: true,
        assignedCheckpointId: 'cp-1',
      );

      expect(repo.lastReview?['rallyId'], 'rally-1');
      expect(repo.lastReview?['uid'], 'u1');
      expect(repo.lastReview?['accept'], true);
      expect(repo.lastReview?['assignedCheckpointId'], 'cp-1');

      await cubit.close();
      repo.dispose();
    });
  });
}
