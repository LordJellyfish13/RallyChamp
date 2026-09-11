import 'package:equatable/equatable.dart';

import '../data/staff_application_summary.dart';

sealed class ApplicationsReviewState extends Equatable {
  const ApplicationsReviewState();

  @override
  List<Object?> get props => [];
}

class ApplicationsReviewLoading extends ApplicationsReviewState {
  const ApplicationsReviewLoading();
}

class ApplicationsReviewLoaded extends ApplicationsReviewState {
  const ApplicationsReviewLoaded(this.applications);

  final List<StaffApplicationSummary> applications;

  @override
  List<Object?> get props => [applications];
}

class ApplicationsReviewError extends ApplicationsReviewState {
  const ApplicationsReviewError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
