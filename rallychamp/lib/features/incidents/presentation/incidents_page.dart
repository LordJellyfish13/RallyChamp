import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/contact/call_link.dart';
import '../../../core/map/directions_link.dart';
import '../../../core/theme/app_colors.dart';
import '../bloc/incidents_cubit.dart';
import '../bloc/incidents_state.dart';
import '../data/incident.dart';
import '../data/incident_repository.dart';

/// The reports behind the public alerts, for the people who have to act on
/// them. Staff-only by security rule, so this is never reachable in a
/// meaningful way for a spectator.
class IncidentsPage extends StatelessWidget {
  const IncidentsPage({super.key, required this.rallyId, this.isAdmin = false});

  final String rallyId;

  /// Only an organizer can dispatch or close an incident; staff see the
  /// same reports read-only, which is what lets a marshal check whether
  /// the thing they reported has been picked up.
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => IncidentsCubit(IncidentRepository(), rallyId),
      child: Scaffold(
        appBar: AppBar(title: const Text('Incidents')),
        body: BlocBuilder<IncidentsCubit, IncidentsState>(
          builder: (context, state) {
            switch (state) {
              case IncidentsLoading():
                return const Center(child: CircularProgressIndicator());
              case IncidentsError(:final message):
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Could not load incidents: $message'),
                  ),
                );
              case IncidentsLoaded(:final incidents):
                if (incidents.isEmpty) {
                  return const Center(child: Text('No incidents reported.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: incidents.length,
                  itemBuilder: (context, index) => _IncidentCard(
                    incident: incidents[index],
                    isAdmin: isAdmin,
                  ),
                );
            }
          },
        ),
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident, required this.isAdmin});

  final Incident incident;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final resolved = incident.isResolved;
    // Only an unresolved incident gets the loud treatment. A resolved one
    // is history, and history shouldn't keep shouting.
    final accent = resolved ? AppColors.statusRunning : AppColors.statusStopped;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: accent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  resolved
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  color: AppColors.surface,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    incident.status.label.toUpperCase(),
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.surface,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Text(
                  DateFormat.Hm().format(incident.createdAt),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.surface,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  incident.crewOk ? 'Crew OK' : 'Crew may be hurt',
                  style: textTheme.titleMedium?.copyWith(
                    color: incident.crewOk
                        ? AppColors.statusRunningText
                        : AppColors.statusStoppedText,
                  ),
                ),
                if (incident.roadBlocked)
                  Text(
                    'Road blocked — stage cannot continue',
                    style: textTheme.bodyMedium,
                  ),
                if (incident.helpRequested.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final kind in incident.helpRequested)
                        Chip(
                          label: Text(kind.label),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                ],
                if (incident.note != null) ...[
                  const SizedBox(height: 8),
                  Text(incident.note!),
                ],
                const SizedBox(height: 12),
                Text(
                  'Reported by ${incident.reporterName}',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (incident.reporterPhone.isNotEmpty)
                      FilledButton.tonalIcon(
                        onPressed: () => callNumber(incident.reporterPhone),
                        icon: const Icon(Icons.call),
                        label: const Text('Call reporter'),
                      ),
                    if (incident.location != null)
                      OutlinedButton.icon(
                        onPressed: () => openDirections(incident.location!),
                        icon: const Icon(Icons.directions),
                        label: const Text('Directions'),
                      ),
                    if (isAdmin && incident.status == IncidentStatus.open)
                      OutlinedButton.icon(
                        onPressed: () => _setStatus(
                          context,
                          IncidentStatus.responding,
                        ),
                        icon: const Icon(Icons.local_shipping_outlined),
                        label: const Text('Help sent'),
                      ),
                    if (isAdmin && !resolved)
                      OutlinedButton.icon(
                        onPressed: () =>
                            _setStatus(context, IncidentStatus.resolved),
                        icon: const Icon(Icons.check),
                        label: const Text('Resolve'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setStatus(BuildContext context, IncidentStatus status) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<IncidentsCubit>().updateStatus(
        incident: incident,
        status: status,
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not update: $e')));
    }
  }
}
