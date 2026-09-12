import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class Stage {
  const Stage({
    required this.id,
    required this.name,
    required this.order,
    required this.route,
  });

  factory Stage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawRoute = data['route'] as List<dynamic>? ?? const [];
    return Stage(
      id: doc.id,
      name: data['name'] as String? ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
      route: rawRoute
          .cast<Map<String, dynamic>>()
          .map(
            (point) => LatLng(
              (point['lat'] as num).toDouble(),
              (point['lng'] as num).toDouble(),
            ),
          )
          .toList(),
    );
  }

  final String id;
  final String name;
  final int order;
  final List<LatLng> route;
}
