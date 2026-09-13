import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/location/current_position.dart';
import '../../../core/theme/app_colors.dart';
import '../../applications/data/applications_repository.dart';
import '../../rallies/data/rally_repository.dart';
import '../../status/bloc/my_assignment_cubit.dart';
import '../../status/bloc/my_assignment_state.dart';
import '../bloc/report_incident_cubit.dart';
import '../data/incident.dart';
import '../data/incident_repository.dart';

/// The crash report. Three questions and a button, because it's filled in
/// by someone standing at the side of a stage who would rather be looking
/// at the car — everything that can be answered for them (who they are,
/// which checkpoint, where they're standing) is, and nothing optional
/// blocks the send.
class ReportIncidentPage extends StatelessWidget {
  const ReportIncidentPage({super.key, required this.rallyId});

  final String rallyId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ReportIncidentCubit(IncidentRepository(), rallyId),
        ),
        // Fills in the reporter's name and assigned checkpoint whichever
        // way they got here — the map's SOS button doesn't otherwise know
        // any of it.
        BlocProvider(
          create: (_) => MyAssignmentCubit(
            ApplicationsRepository(),
            RallyRepository(),
            rallyId,
          ),
        ),
      ],
      child: const _ReportIncidentView(),
    );
  }
}

class _ReportIncidentView extends StatefulWidget {
  const _ReportIncidentView();

  @override
  State<_ReportIncidentView> createState() => _ReportIncidentViewState();
}

class _ReportIncidentViewState extends State<_ReportIncidentView> {
  bool _crewOk = true;
  bool _roadBlocked = false;
  final Set<HelpKind> _help = {};
  final _noteController = TextEditingController();

  GeoPoint? _location;

  @override
  void initState() {
    super.initState();
    _captureLocation();
  }

  /// Best-effort and fire-and-forget: a reporter may have walked away from
  /// their post to reach the car, so their own coordinates are worth more
  /// than the checkpoint's — but a slow or refused fix must never be the
  /// reason an alert didn't go out.
  Future<void> _captureLocation() async {
    try {
      final position = await currentPosition();
      if (mounted) {
        setState(
          () => _location = GeoPoint(position.latitude, position.longitude),
        );
      }
    } catch (_) {
      // Reported without coordinates; the checkpoint still narrows it down.
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReportIncidentCubit, ReportIncidentState>(
      listener: (context, state) {
        if (state is ReportIncidentSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incident reported — organizers alerted')),
          );
          Navigator.of(context).pop();
        }
        if (state is ReportIncidentFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not report: ${state.message}')),
          );
        }
      },
      builder: (context, state) {
        final submitting = state is ReportIncidentSubmitting;
        return Scaffold(
          appBar: AppBar(title: const Text('Report incident')),
          body: BlocBuilder<MyAssignmentCubit, MyAssignmentState>(
            builder: (context, assignment) {
              final application = assignment is MyAssignmentLoaded
                  ? assignment.application
                  : null;
              final checkpoint = assignment is MyAssignmentLoaded
                  ? assignment.checkpoint
                  : null;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    checkpoint == null
                        ? 'Reporting from your location'
                        : 'Reporting from ${checkpoint.code}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: _crewOk,
                          onChanged: (value) => setState(() => _crewOk = value),
                          title: const Text('Crew is OK'),
                          subtitle: Text(
                            _crewOk
                                ? 'Nobody appears hurt'
                                : 'Someone may be hurt',
                          ),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          value: _roadBlocked,
                          onChanged: (value) =>
                              setState(() => _roadBlocked = value),
                          title: const Text('Road is blocked'),
                          subtitle: const Text('The stage cannot continue'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'What do you need?',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final kind in HelpKind.values)
                        FilterChip(
                          label: Text(kind.label),
                          selected: _help.contains(kind),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _help.add(kind);
                            } else {
                              _help.remove(kind);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _noteController,
                    maxLength: 200,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Anything else? (optional)',
                      hintText: 'Car number, what you can see…',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.statusStopped,
                      ),
                      onPressed: submitting
                          ? null
                          : () => _submit(
                              context,
                              application?.applicantName,
                              application?.applicantPhone,
                              checkpoint?.id,
                              checkpoint?.code,
                            ),
                      icon: submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.warning_amber_rounded),
                      label: Text(
                        submitting ? 'Reporting…' : 'Report incident',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Organizers are alerted immediately. Photos can be added '
                    'later — don\'t wait for one now.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _submit(
    BuildContext context,
    String? reporterName,
    String? reporterPhone,
    String? checkpointId,
    String? checkpointCode,
  ) {
    context.read<ReportIncidentCubit>().submit(
      reporterName: reporterName ?? 'Unknown',
      reporterPhone: reporterPhone ?? '',
      crewOk: _crewOk,
      roadBlocked: _roadBlocked,
      helpRequested: _help.toList(),
      checkpointId: checkpointId,
      checkpointCode: checkpointCode,
      location: _location,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );
  }
}
