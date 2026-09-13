import 'package:cloud_firestore/cloud_firestore.dart';

enum EntryStatus { pending, accepted, rejected }

extension EntryStatusX on EntryStatus {
  String get firestoreValue => switch (this) {
    EntryStatus.pending => 'pending',
    EntryStatus.accepted => 'accepted',
    EntryStatus.rejected => 'rejected',
  };

  String get label => switch (this) {
    EntryStatus.pending => 'Pending',
    EntryStatus.accepted => 'Accepted',
    EntryStatus.rejected => 'Rejected',
  };
}

EntryStatus _statusFromFirestore(String? value) => switch (value) {
  'accepted' => EntryStatus.accepted,
  'rejected' => EntryStatus.rejected,
  _ => EntryStatus.pending,
};

/// A team/competitor entry — the public half. Car number, class, team and
/// crew names are meant to be public before the rally (dev_notes.md §5);
/// phone and OIB live in a separate `private/contact` document, because
/// security rules are per-document and this one is world-readable once the
/// rally is published.
class Entry {
  const Entry({
    required this.id,
    required this.uid,
    required this.teamName,
    required this.driverName,
    required this.coDriverName,
    required this.carNumber,
    required this.carClass,
    required this.status,
    required this.appliedAt,
  });

  factory Entry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Entry(
      id: doc.id,
      // Entries created before auto-ids have no `uid` field — their
      // document id *is* the owner's uid.
      uid: data['uid'] as String? ?? doc.id,
      teamName: data['teamName'] as String? ?? '',
      driverName: data['driverName'] as String? ?? '',
      coDriverName: data['coDriverName'] as String? ?? '',
      carNumber: data['carNumber'] as String? ?? '',
      carClass: data['class'] as String? ?? '',
      status: _statusFromFirestore(data['status'] as String?),
      appliedAt: (data['appliedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  final String id;

  /// Who entered. Ownership lives here rather than in the document id, so
  /// one account can enter more than one car — a club almost always runs
  /// several crews.
  final String uid;

  final String teamName;
  final String driverName;

  /// Paired with the driver everywhere it's shown — a rally crew is two
  /// people, and Gabriel's own prototype surfaced that the schema had
  /// originally missed the co-driver entirely (dev_notes.md §5).
  final String coDriverName;

  final String carNumber;
  final String carClass;
  final EntryStatus status;
  final DateTime appliedAt;

  bool get isPending => status == EntryStatus.pending;
}

/// Entrants' contact details, from the admin-only `private/contact`
/// subdocument. Never merged into [Entry]: keeping them in a separate type
/// makes it obvious at every call site that showing these needs organizer
/// access, and that they were fetched deliberately rather than riding
/// along with a public list.
class EntryContact {
  const EntryContact({required this.phone, required this.email});

  factory EntryContact.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return EntryContact(
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String? ?? '',
    );
  }

  final String phone;
  final String email;
}

/// Car numbers that more than one entry is claiming. Nothing stops two
/// teams typing the same number — real rallies have numbers assigned by
/// the organizer — so the review screen flags the clash rather than
/// letting it surface on race day.
Set<String> duplicateCarNumbers(Iterable<Entry> entries) {
  final seen = <String>{};
  final duplicates = <String>{};
  for (final entry in entries) {
    if (entry.status == EntryStatus.rejected) continue;
    final number = entry.carNumber.trim();
    if (number.isEmpty) continue;
    if (!seen.add(number)) duplicates.add(number);
  }
  return duplicates;
}

/// Car numbers sort the way a start list reads: 1, 2, 10 — not 1, 10, 2.
/// Falls back to plain text for anything non-numeric ("0", "A1").
int compareCarNumbers(String a, String b) {
  final left = int.tryParse(a);
  final right = int.tryParse(b);
  if (left != null && right != null) return left.compareTo(right);
  if (left != null) return -1;
  if (right != null) return 1;
  return a.compareTo(b);
}
