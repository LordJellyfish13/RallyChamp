import 'package:flutter/material.dart';

import '../../applications/presentation/applications_review_page.dart';
import '../data/rally_summary.dart';
import 'checkpoints_page.dart';

/// Organizer hub for a single rally: checkpoints and application review.
class RallyDetailPage extends StatelessWidget {
  const RallyDetailPage({super.key, required this.rally});

  final RallySummary rally;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(rally.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(rally.description),
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
        ],
      ),
    );
  }
}
