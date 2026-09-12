import 'package:flutter_map/flutter_map.dart';
import 'package:path_provider/path_provider.dart';

/// Sets up flutter_map's own built-in tile cache (no external package
/// needed — see dev_notes.md §5 "Offline tile caching" for why: the one
/// external option, `flutter_map_tile_caching`, doesn't yet support the
/// `latlong2`/`flutter_map` versions this app uses).
///
/// Two changes from the library defaults, both required for tiles to
/// actually survive a trip into the forest with no signal:
/// - **Persistent storage**: defaults to a platform cache directory the OS
///   may clear at any time; this points it at the app's own support
///   directory instead, which isn't cleared automatically.
/// - **`overrideFreshAge` set very long**: by default, a cached tile is
///   only served without a network round-trip while it's "fresh" — once
///   it goes stale (a matter of hours, per the tile server's own
///   Cache-Control headers), flutter_map tries the network again on every
///   view, and with no signal that attempt just fails, showing a blank
///   tile instead of the perfectly good one already on disk. Treating
///   every cached tile as fresh for a year sidesteps that entirely: once
///   a tile is cached (from ordinary viewing, or a deliberate "download
///   for offline use"), it's always served from disk unless the app
///   fetches something new.
///
/// Call once at startup, before any `FlutterMap` is built.
Future<void> initializeMapCache() async {
  final directory = await getApplicationSupportDirectory();
  BuiltInMapCachingProvider.getOrCreateInstance(
    cacheDirectory: directory.path,
    overrideFreshAge: const Duration(days: 365),
  );
}
