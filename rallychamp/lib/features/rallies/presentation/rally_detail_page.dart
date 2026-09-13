import 'package:flutter/material.dart';

import '../../applications/presentation/applications_review_page.dart';
import '../../applications/presentation/people_page.dart';
import '../../entries/presentation/entries_review_page.dart';
import '../../incidents/presentation/incidents_page.dart';
import '../../results/presentation/enter_results_page.dart';
import '../data/rally_repository.dart';
import '../data/rally_summary.dart';
import 'checkpoints_page.dart';
import 'edit_rally_page.dart';
import 'stages_page.dart';

/// Organizer hub for a single rally: checkpoints and application review.
class RallyDetailPage extends StatefulWidget {
  const RallyDetailPage({super.key, required this.rally});

  final RallySummary rally;

  @override
  State<RallyDetailPage> createState() => _RallyDetailPageState();
}

class _RallyDetailPageState extends State<RallyDetailPage> {
  /// Starts as what `MyRalliesPage` handed over, and is replaced by the
  /// edit screen's result so the header doesn't keep showing the old name
  /// and dates until the list behind this page reloads.
  late RallySummary rally = widget.rally;

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditRallyPage(rally: rally)),
    );
    if (!(changed ?? false) || !mounted) return;
    final refreshed = await RallyRepository().getRallySummary(rally.id);
    if (refreshed != null && mounted) setState(() => rally = refreshed);
  }

  @override
  Widget build(BuildContext context) {
    final dates = rallyDateRange(rally.startDate, rally.endDate);
    return Scaffold(
      appBar: AppBar(
        title: Text(rally.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit rally details',
            onPressed: _edit,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(rally.description),
          if (dates.isNotEmpty || rally.locationName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (dates.isNotEmpty) dates,
                if (rally.locationName.isNotEmpty) rally.locationName,
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Checkpoints'),
              subtitle: const Text('Viewing points, parking, box'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CheckpointsPage(rallyId: rally.id),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.route_outlined),
              title: const Text('Stages & routes'),
              subtitle: const Text('Draw or record each stage\'s route'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StagesPage(rallyId: rally.id),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.assignment_outlined),
              title: const Text('Applications'),
              subtitle: const Text('Review marshals, judges, and teams'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ApplicationsReviewPage(rallyId: rally.id),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.directions_car_outlined),
              title: const Text('Entries'),
              subtitle: const Text('Accept teams onto the start list'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EntriesReviewPage(rallyId: rally.id),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Results'),
              subtitle: const Text('Record stage times as they come in'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EnterResultsPage(rallyId: rally.id),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.warning_amber_rounded),
              title: const Text('Incidents'),
              subtitle: const Text('Crash reports, and dispatching help'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        IncidentsPage(rallyId: rally.id, isAdmin: true),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('People'),
              subtitle: const Text('Accepted marshals and judges, by checkpoint'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PeoplePage(rallyId: rally.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
