import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

import 'tile_math.dart';

/// The zoom range a "download for offline use" covers — roughly a
/// whole-stage overview (13) down to close enough to actually navigate by
/// (17). Deliberately a full bounding box around the rally's checkpoints
/// and routes, not a route-hugging corridor — simpler, and comfortably
/// within a few tens of MB for a typical club-rally area (see dev_notes.md
/// §5 "Offline tile caching"); revisit with a corridor if a much larger
/// rally ever makes that matter.
const offlineDownloadMinZoom = 13;
const offlineDownloadMaxZoom = 17;

class TileDownloadProgress {
  const TileDownloadProgress({
    required this.completed,
    required this.total,
    required this.failed,
  });

  final int completed;
  final int total;
  final int failed;

  bool get isDone => completed >= total;
}

/// Downloads and caches every tile covering [bounds] so the map keeps
/// working with no signal. Writes through flutter_map's own built-in
/// caching provider (the same one `TileLayer` already writes to on every
/// ordinary view — see `offline_cache.dart`), so a pre-fetched tile is
/// indistinguishable from one cached incidentally while browsing online.
///
/// Sequential, not parallel, with a small delay between requests — OSM's
/// tile usage policy caps bulk use at roughly 2 requests/second.
Stream<TileDownloadProgress> downloadTilesForOfflineUse(
  LatLngBounds bounds, {
  int minZoom = offlineDownloadMinZoom,
  int maxZoom = offlineDownloadMaxZoom,
}) async* {
  final tiles = tilesForBounds(bounds, minZoom: minZoom, maxZoom: maxZoom);
  final cachingProvider = BuiltInMapCachingProvider.getOrCreateInstance();
  final client = http.Client();
  var completed = 0;
  var failed = 0;

  try {
    for (final tile in tiles) {
      final url =
          'https://tile.openstreetmap.org/${tile.z}/${tile.x}/${tile.y}.png';
      try {
        final response = await client.get(
          Uri.parse(url),
          headers: const {'User-Agent': 'flutter_map (com.example.rallychamp)'},
        );
        if (response.statusCode == 200) {
          await cachingProvider.putTile(
            url: url,
            metadata: CachedMapTileMetadata.fromHttpHeaders(response.headers),
            bytes: response.bodyBytes,
          );
        } else {
          failed++;
        }
      } catch (_) {
        failed++;
      }
      completed++;
      yield TileDownloadProgress(
        completed: completed,
        total: tiles.length,
        failed: failed,
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  } finally {
    client.close();
  }
}
