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

class Checkpoint {
  const Checkpoint({
    required this.id,
    required this.code,
    required this.kind,
    this.location,
  });

  factory Checkpoint.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Checkpoint(
      id: doc.id,
      code: data['code'] as String? ?? '',
      kind: _kindFromFirestore(data['kind'] as String?),
      location: data['location'] as GeoPoint?,
    );
  }

  final String id;
  final String code;
  final CheckpointKind kind;

  /// Null for checkpoints added before location capture existed, or if
  /// GPS wasn't available at the time — the map just skips those.
  final GeoPoint? location;
}
