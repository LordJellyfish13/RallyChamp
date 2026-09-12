import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rallychamp/core/map/tile_math.dart';

void main() {
  group('tilesForBounds', () {
    test('a single zoom level covers the requested bounds', () {
      // Zagreb-ish box, well documented tile numbers at zoom 10.
      final bounds = LatLngBounds(
        const LatLng(45.7, 15.9),
        const LatLng(45.85, 16.1),
      );

      final tiles = tilesForBounds(bounds, minZoom: 10, maxZoom: 10);

      expect(tiles, isNotEmpty);
      expect(tiles.every((t) => t.z == 10), isTrue);
      // Every tile should be within a tight, contiguous x/y range.
      final xs = tiles.map((t) => t.x).toSet();
      final ys = tiles.map((t) => t.y).toSet();
      expect(xs.length * ys.length, tiles.length);
    });

    test('covers every zoom level in the requested range', () {
      final bounds = LatLngBounds(
        const LatLng(45.3, 14.4),
        const LatLng(45.31, 14.41),
      );

      final tiles = tilesForBounds(bounds, minZoom: 12, maxZoom: 14);

      expect(tiles.map((t) => t.z).toSet(), {12, 13, 14});
    });

    test('a single point still yields exactly one tile per zoom', () {
      final bounds = LatLngBounds(
        const LatLng(45.3, 14.4),
        const LatLng(45.3, 14.4),
      );

      final tiles = tilesForBounds(bounds, minZoom: 15, maxZoom: 15);

      expect(tiles, hasLength(1));
    });

    test('higher zoom levels produce more tiles for the same area', () {
      final bounds = LatLngBounds(
        const LatLng(45.0, 15.0),
        const LatLng(45.5, 15.5),
      );

      final lowZoom = tilesForBounds(bounds, minZoom: 8, maxZoom: 8);
      final highZoom = tilesForBounds(bounds, minZoom: 12, maxZoom: 12);

      expect(highZoom.length, greaterThan(lowZoom.length));
    });
  });
}
