import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rallychamp/features/applications/data/applications_repository.dart';
import 'package:rallychamp/features/entries/bloc/entries_cubit.dart';
import 'package:rallychamp/features/entries/data/entry.dart';

class _FakeApplicationsRepository extends Fake implements ApplicationsRepository {
  final _controller = StreamController<List<Entry>>();
  Map<String, Object?>? lastReview;

  @override
  Stream<List<Entry>> watchEntries(String rallyId) => _controller.stream;

  @override
  Future<void> reviewEntry({
    required String rallyId,
    required String entryId,
    required bool accept,
  }) async {
    lastReview = {'entryId': entryId, 'accept': accept};
  }

  @override
  Future<EntryContact?> getEntryContact({
    required String rallyId,
    required String entryId,
  }) async => const EntryContact(phone: '0911234567', email: 'a@b.c');

  void emit(List<Entry> entries) => _controller.add(entries);
  void dispose() => _controller.close();
}

Entry _entry({
  String id = 'e1',
  String carNumber = '1',
  EntryStatus status = EntryStatus.pending,
}) {
  return Entry(
    id: id,
    uid: 'u1',
    teamName: 'Team Šuma',
    driverName: 'Ana',
    coDriverName: 'Iva',
    carNumber: carNumber,
    carClass: 'N4',
    status: status,
    appliedAt: DateTime(2026, 9, 13),
  );
}

void main() {
  group('compareCarNumbers', () {
    test('sorts the way a start list reads, not alphabetically', () {
      final numbers = ['10', '2', '1']..sort(compareCarNumbers);
      expect(numbers, ['1', '2', '10']);
    });

    test('puts non-numeric numbers after numeric ones', () {
      final numbers = ['A1', '3']..sort(compareCarNumbers);
      expect(numbers, ['3', 'A1']);
    });
  });

  group('duplicateCarNumbers', () {
    test('flags a number two live entries are both claiming', () {
      final clashes = duplicateCarNumbers([
        _entry(id: 'e1', carNumber: '7', status: EntryStatus.accepted),
        _entry(id: 'e2', carNumber: '7'),
        _entry(id: 'e3', carNumber: '9'),
      ]);
      expect(clashes, {'7'});
    });

    test('a rejected entry does not clash with anyone', () {
      final clashes = duplicateCarNumbers([
        _entry(id: 'e1', carNumber: '7', status: EntryStatus.accepted),
        _entry(id: 'e2', carNumber: '7', status: EntryStatus.rejected),
      ]);
      expect(clashes, isEmpty);
    });

    test('blank numbers are not treated as clashing with each other', () {
      final clashes = duplicateCarNumbers([
        _entry(id: 'e1', carNumber: ''),
        _entry(id: 'e2', carNumber: '  '),
      ]);
      expect(clashes, isEmpty);
    });
  });

  group('EntriesCubit', () {
    test('starts loading', () async {
      final repo = _FakeApplicationsRepository();
      final cubit = EntriesCubit(repo, 'rally-1');

      expect(cubit.state, isA<EntriesLoading>());

      await cubit.close();
      repo.dispose();
    });

    test('accepted exposes only the confirmed start list', () async {
      final repo = _FakeApplicationsRepository();
      final cubit = EntriesCubit(repo, 'rally-1');

      repo.emit([
        _entry(id: 'e1', status: EntryStatus.accepted),
        _entry(id: 'e2', status: EntryStatus.pending),
        _entry(id: 'e3', status: EntryStatus.rejected),
      ]);
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as EntriesLoaded;
      expect(state.entries, hasLength(3));
      expect(state.accepted.map((e) => e.id), ['e1']);

      await cubit.close();
      repo.dispose();
    });

    test('review delegates to the repository', () async {
      final repo = _FakeApplicationsRepository();
      final cubit = EntriesCubit(repo, 'rally-1');

      await cubit.review(entryId: 'e7', accept: true);

      expect(repo.lastReview?['entryId'], 'e7');
      expect(repo.lastReview?['accept'], true);

      await cubit.close();
      repo.dispose();
    });

    test('contactFor fetches the admin-only details on demand', () async {
      final repo = _FakeApplicationsRepository();
      final cubit = EntriesCubit(repo, 'rally-1');

      final contact = await cubit.contactFor('e1');

      expect(contact?.phone, '0911234567');

      await cubit.close();
      repo.dispose();
    });
  });
}
