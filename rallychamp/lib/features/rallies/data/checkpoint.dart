import 'package:cloud_firestore/cloud_firestore.dart';

enum CheckpointKind { viewing, parking, box }

extension CheckpointKindX on CheckpointKind {
  String get firestoreValue => switch (this) {
    CheckpointKind.viewing => 'viewing',
    CheckpointKind.parking => 'parking',
    CheckpointKind.box => 'box',
  };

  String get label => switch (this) {
    CheckpointKind.viewing => 'Viewing / marshal point',
    CheckpointKind.parking => 'Parking',
    CheckpointKind.box => 'Box / service park',
  };
}

CheckpointKind _kindFromFirestore(String? value) {
  switch (value) {
    case 'parking':
      return CheckpointKind.parking;
    case 'box':
      return CheckpointKind.box;
    default:
      return CheckpointKind.viewing;
  }
}

/// Splits a code like "RSV12" into its prefix and number. Anything that
/// doesn't end in digits has no number to continue from.
({String prefix, int number})? _parseCode(String code) {
  final match = RegExp(r'^(.*?)(\d+)$').firstMatch(code.trim());
  if (match == null) return null;
  return (prefix: match.group(1)!, number: int.parse(match.group(2)!));
}

/// The next code to suggest, given the codes already used *on the same
/// stage*. Rally checkpoints run in sequences (R1, R2, R3…) and each stage
/// numbers from 1 again, which is exactly why the suggestion is scoped to
/// one stage rather than the whole rally.
///
/// Picks the most-used prefix and continues it, so a stage holding R1–R5
/// and one "Box" suggests R6 rather than "Box1". Returns null when there's
/// nothing to continue from, leaving the field empty for a fresh start.
String? nextCheckpointCode(Iterable<String> existingCodes) {
  final highestByPrefix = <String, int>{};
  final countByPrefix = <String, int>{};
  for (final code in existingCodes) {
    final parsed = _parseCode(code);
    if (parsed == null) continue;
    countByPrefix[parsed.prefix] = (countByPrefix[parsed.prefix] ?? 0) + 1;
    final highest = highestByPrefix[parsed.prefix];
    if (highest == null || parsed.number > highest) {
      highestByPrefix[parsed.prefix] = parsed.number;
    }
  }
  if (countByPrefix.isEmpty) return null;

  var best = countByPrefix.keys.first;
  for (final prefix in countByPrefix.keys) {
    final betterCount = countByPrefix[prefix]! > countByPrefix[best]!;
    final tiedButHigher = countByPrefix[prefix] == countByPrefix[best] &&
        highestByPrefix[prefix]! > highestByPrefix[best]!;
    if (betterCount || tiedButHigher) best = prefix;
  }
  return '$best${highestByPrefix[best]! + 1}';
}

class Checkpoint {
  const Checkpoint({
    required this.id,
    required this.code,
    required this.kind,
    this.stageId,
    this.location,
  });

  factory Checkpoint.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Checkpoint(
      id: doc.id,
      code: data['code'] as String? ?? '',
      kind: _kindFromFirestore(data['kind'] as String?),
      stageId: data['stageId'] as String?,
      location: data['location'] as GeoPoint?,
    );
  }

  final String id;
  final String code;
  final CheckpointKind kind;

  /// Which stage this checkpoint belongs to. Null for checkpoints created
  /// before this existed — §9 always planned the field, the first
  /// implementation just skipped it, which is why a rally could end up
  /// with three indistinguishable "R1"s.
  final String? stageId;

  /// Null for checkpoints added before location capture existed, or if
  /// GPS wasn't available at the time — the map just skips those.
  final GeoPoint? location;
}
