import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/contact/call_link.dart';
import '../../../core/theme/app_colors.dart';
import '../../applications/data/applications_repository.dart';
import '../bloc/entries_cubit.dart';
import '../data/entry.dart';
import 'entry_card.dart';

/// The organizer's side of the entry list: accept or reject the teams who
/// applied, and reach the ones already in. Public read of `entries` means
/// anyone can see an accepted start list; this screen is where it gets
/// decided.
class EntriesReviewPage extends StatelessWidget {
  const EntriesReviewPage({super.key, required this.rallyId});

  final String rallyId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => EntriesCubit(ApplicationsRepository(), rallyId),
      child: Scaffold(
        appBar: AppBar(title: const Text('Entries')),
        body: BlocBuilder<EntriesCubit, EntriesState>(
          builder: (context, state) {
            switch (state) {
              case EntriesLoading():
                return const Center(child: CircularProgressIndicator());
              case EntriesError(:final message):
                return Center(child: Text('Could not load entries: $message'));
              case EntriesLoaded(:final entries):
                if (entries.isEmpty) {
                  return const Center(child: Text('No entries yet.'));
                }
                final clashes = duplicateCarNumbers(entries);
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: entries.length,
                  itemBuilder: (context, index) => _ReviewableEntry(
                    entry: entries[index],
                    clashesOnNumber: clashes.contains(
                      entries[index].carNumber.trim(),
                    ),
                  ),
                );
            }
          },
        ),
      ),
    );
  }
}

class _ReviewableEntry extends StatelessWidget {
  const _ReviewableEntry({required this.entry, this.clashesOnNumber = false});

  final Entry entry;

  /// Another non-rejected entry claims the same car number. Worth saying
  /// out loud here: real rallies have numbers assigned by the organizer,
  /// but entrants type their own, and a clash discovered on race day is a
  /// much worse problem than one flagged during review.
  final bool clashesOnNumber;

  @override
  Widget build(BuildContext context) {
    return EntryCard(
      entry: entry,
      onTap: () => _showContact(context),
      trailing: _StatusBadge(status: entry.status),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (clashesOnNumber)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: AppColors.statusStoppedText,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Car number ${entry.carNumber} is claimed by another entry',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.statusStoppedText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (entry.isPending)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _review(context, accept: false),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => _review(context, accept: true),
                  child: const Text('Accept'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _review(BuildContext context, {required bool accept}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<EntriesCubit>().review(
        entryId: entry.id,
        accept: accept,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update entry: $e')),
      );
    }
  }

  /// Fetched on tap rather than with the list — it's an extra read per
  /// entry, and only worth doing for the competitor being contacted.
  Future<void> _showContact(BuildContext context) async {
    final cubit = context.read<EntriesCubit>();
    final contact = await cubit.contactFor(entry.id);
    if (!context.mounted) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${entry.carNumber} · ${entry.driverName}',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (contact == null)
                const Text('No contact details on file.')
              else ...[
                if (contact.email.isNotEmpty) Text(contact.email),
                const SizedBox(height: 12),
                if (contact.phone.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => callNumber(contact.phone),
                      icon: const Icon(Icons.call),
                      label: Text('Call ${contact.phone}'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final EntryStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      EntryStatus.accepted => (AppColors.successTint, AppColors.success),
      EntryStatus.rejected => (AppColors.neutralTint, AppColors.inkSoft),
      EntryStatus.pending => (AppColors.primaryTint, AppColors.primaryDark),
    };
    return Chip(
      label: Text(status.label),
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
