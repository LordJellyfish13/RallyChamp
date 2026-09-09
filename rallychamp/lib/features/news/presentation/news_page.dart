import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../applications/data/staff_role.dart';
import '../../applications/presentation/staff_application_form.dart';
import '../../applications/presentation/team_entry_form.dart';
import '../bloc/news_cubit.dart';
import '../bloc/news_state.dart';
import '../data/news_post.dart';
import '../data/news_repository.dart';

class NewsPage extends StatelessWidget {
  const NewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NewsCubit(NewsRepository()),
      child: const _NewsView(),
    );
  }
}

class _NewsView extends StatelessWidget {
  const _NewsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('News')),
      body: BlocBuilder<NewsCubit, NewsState>(
        builder: (context, state) {
          switch (state) {
            case NewsLoading():
              return const Center(child: CircularProgressIndicator());
            case NewsError(:final message):
              return Center(child: Text('Could not load news: $message'));
            case NewsLoaded(:final posts):
              if (posts.isEmpty) {
                return const Center(child: Text('No news yet.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: posts.length,
                itemBuilder: (context, index) =>
                    _NewsCard(post: posts[index]),
              );
          }
        },
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.post});

  final NewsPost post;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TypeBadge(type: post.type),
                const Spacer(),
                Text(
                  DateFormat.yMMMd().format(post.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(post.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(post.body),
            if (post.rallyId != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: () =>
                      _showApplySheet(context, post.rallyId!, post.title),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final NewsPostType type;

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      NewsPostType.newRally => 'New rally',
      NewsPostType.victory => 'Victory',
      NewsPostType.recruiting => 'Recruiting',
      NewsPostType.announcement => 'Announcement',
    };
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

void _showApplySheet(BuildContext context, String rallyId, String rallyName) {
  final cubit = context.read<NewsCubit>();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Apply for $rallyName',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Spectator'),
              subtitle: const Text('Follow this rally for live alerts'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await cubit.followRally(rallyId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Following this rally')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Marshal / Volunteer'),
              onTap: () => _openStaffApplication(
                sheetContext,
                rallyId,
                StaffRole.marshal,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.gavel_outlined),
              title: const Text('Judge'),
              onTap: () =>
                  _openStaffApplication(sheetContext, rallyId, StaffRole.judge),
            ),
            ListTile(
              leading: const Icon(Icons.directions_car_outlined),
              title: const Text('Team / Competitor'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(sheetContext).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TeamEntryForm(rallyId: rallyId),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

void _openStaffApplication(
  BuildContext sheetContext,
  String rallyId,
  StaffRole role,
) {
  Navigator.of(sheetContext).pop();
  Navigator.of(sheetContext).push(
    MaterialPageRoute<void>(
      builder: (_) => StaffApplicationForm(rallyId: rallyId, role: role),
    ),
  );
}
