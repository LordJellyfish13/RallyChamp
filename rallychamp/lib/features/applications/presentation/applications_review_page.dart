import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../rallies/data/checkpoint.dart';
import '../../rallies/data/rally_repository.dart';
import '../bloc/applications_review_cubit.dart';
import '../bloc/applications_review_state.dart';
import '../data/applications_repository.dart';
import '../data/staff_application_summary.dart';
import '../data/staff_role.dart';

class ApplicationsReviewPage extends StatelessWidget {
  const ApplicationsReviewPage({super.key, required this.rallyId});

  final String rallyId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ApplicationsReviewCubit(ApplicationsRepository(), rallyId),
      child: _ApplicationsReviewView(rallyId: rallyId),
    );
  }
}

class _ApplicationsReviewView extends StatefulWidget {
  const _ApplicationsReviewView({required this.rallyId});

  final String rallyId;

  @override
  State<_ApplicationsReviewView> createState() =>
      _ApplicationsReviewViewState();
}

class _ApplicationsReviewViewState extends State<_ApplicationsReviewView> {
  List<Checkpoint> _checkpoints = const [];

  @override
  void initState() {
    super.initState();
    RallyRepository().watchCheckpoints(widget.rallyId).first.then((
      checkpoints,
    ) {
      if (mounted) setState(() => _checkpoints = checkpoints);
    });
  }

  String? _checkpointCode(String? id) {
    if (id == null) return null;
    for (final checkpoint in _checkpoints) {
      if (checkpoint.id == id) return checkpoint.code;
    }
    return null;
  }

  Future<void> _accept(BuildContext context, StaffApplicationSummary app) async {
    final cubit = context.read<ApplicationsReviewCubit>();
    String? selectedCheckpointId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: Text('Accept ${app.applicantName}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assign to a checkpoint now, or leave unassigned.'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedCheckpointId,
                    decoration: const InputDecoration(labelText: 'Checkpoint'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Unassigned'),
                      ),
                      ..._checkpoints.map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.code),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => selectedCheckpointId = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Accept'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;
    try {
      await cubit.review(
        uid: app.uid,
        accept: true,
        assignedCheckpointId: selectedCheckpointId,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not accept: $e')));
      }
    }
  }

  Future<void> _reject(BuildContext context, StaffApplicationSummary app) async {
    try {
      await context.read<ApplicationsReviewCubit>().review(
        uid: app.uid,
        accept: false,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not reject: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Applications')),
      body: BlocBuilder<ApplicationsReviewCubit, ApplicationsReviewState>(
        builder: (context, state) {
          switch (state) {
            case ApplicationsReviewLoading():
              return const Center(child: CircularProgressIndicator());
            case ApplicationsReviewError(:final message):
              return Center(child: Text('Could not load applications: $message'));
            case ApplicationsReviewLoaded(:final applications):
              if (applications.isEmpty) {
                return const Center(child: Text('No applications yet.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: applications.length,
                itemBuilder: (context, index) {
                  final app = applications[index];
                  final checkpointCode = _checkpointCode(
                    app.assignedCheckpointId,
                  );
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Chip(
                                label: Text(
                                  app.role == StaffRole.judge
                                      ? 'Judge'
                                      : 'Marshal',
                                ),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              const SizedBox(width: 8),
                              _StatusBadge(status: app.status),
                              const Spacer(),
                              Text(
                                DateFormat.yMMMd().format(app.appliedAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            app.applicantName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            app.applicantPhone,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (checkpointCode != null) ...[
                            const SizedBox(height: 4),
                            Text('Assigned to $checkpointCode'),
                          ],
                          if (app.isPending) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _reject(context, app),
                                  child: const Text('Reject'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.tonal(
                                  onPressed: () => _accept(context, app),
                                  child: const Text('Accept'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
          }
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    switch (status) {
      case 'accepted':
        background = AppColors.successTint;
        foreground = AppColors.success;
      case 'rejected':
        background = AppColors.neutralTint;
        foreground = AppColors.inkSoft;
      default:
        background = AppColors.primaryTint;
        foreground = AppColors.primaryDark;
    }
    return Chip(
      label: Text(status),
      backgroundColor: background,
      labelStyle: TextStyle(
        color: foreground,
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
