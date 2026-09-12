import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';

/// A single OSM/slippy-map tile coordinate.
class TileCoordinate {
  const TileCoordinate({required this.z, required this.x, required this.y});

  final int z;
  final int x;
  final int y;
}

int _lonToTileX(double lon, int z) => ((lon + 180) / 360 * (1 << z)).floor();

int _latToTileY(double lat, int z) {
  final latRad = lat * math.pi / 180;
  final sinhInverse = math.log(math.tan(latRad) + 1 / math.cos(latRad));
  return ((1 - sinhInverse / math.pi) / 2 * (1 << z)).floor();
}

/// Every tile covering [bounds] across [minZoom]..[maxZoom] inclusive —
/// used both to run a "download for offline use" and to estimate its size
/// beforehand. Standard slippy-map (Web Mercator) tile math.
List<TileCoordinate> tilesForBounds(
  LatLngBounds bounds, {
  required int minZoom,
  required int maxZoom,
}) {
  final tiles = <TileCoordinate>[];
  for (var z = minZoom; z <= maxZoom; z++) {
    final xMin = _lonToTileX(bounds.west, z);
    final xMax = _lonToTileX(bounds.east, z);
    // Tile y increases southward, so the north edge gives the smaller y.
    final yMin = _latToTileY(bounds.north, z);
    final yMax = _latToTileY(bounds.south, z);
    for (var x = xMin; x <= xMax; x++) {
      for (var y = yMin; y <= yMax; y++) {
        tiles.add(TileCoordinate(z: z, x: x, y: y));
      }
    }
  }
  return tiles;
}
