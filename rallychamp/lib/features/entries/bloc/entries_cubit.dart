import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../applications/data/applications_repository.dart';
import '../data/entry.dart';

sealed class EntriesState extends Equatable {
  const EntriesState();

  @override
  List<Object?> get props => [];
}

class EntriesLoading extends EntriesState {
  const EntriesLoading();
}

class EntriesLoaded extends EntriesState {
  const EntriesLoaded(this.entries);

  final List<Entry> entries;

  /// What the public sees: the start list, not the paperwork. A pending or
  /// rejected entry is between the team and the organizer.
  List<Entry> get accepted => entries
      .where((entry) => entry.status == EntryStatus.accepted)
      .toList();

  /// This person's own entries, whatever their status. Without this an
  /// entrant submits the form and then hears nothing — they only ever
  /// appear once accepted, so "pending" and "rejected" were both
  /// indistinguishable from "lost".
  List<Entry> mine(String? uid) {
    if (uid == null) return const [];
    return entries.where((entry) => entry.uid == uid).toList();
  }

  @override
  List<Object?> get props => [entries];
}

class EntriesError extends EntriesState {
  const EntriesError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class EntriesCubit extends Cubit<EntriesState> {
  EntriesCubit(this._repository, this.rallyId) : super(const EntriesLoading()) {
    _subscription = _repository.watchEntries(rallyId).listen(
      (entries) => emit(EntriesLoaded(entries)),
      onError: (Object error, StackTrace _) {
        if (!isClosed) emit(EntriesError('$error'));
      },
    );
  }

  final ApplicationsRepository _repository;
  final String rallyId;
  late final StreamSubscription<List<Entry>> _subscription;

  Future<void> review({required String entryId, required bool accept}) {
    return _repository.reviewEntry(
      rallyId: rallyId,
      entryId: entryId,
      accept: accept,
    );
  }

  Future<EntryContact?> contactFor(String entryId) {
    return _repository.getEntryContact(rallyId: rallyId, entryId: entryId);
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
