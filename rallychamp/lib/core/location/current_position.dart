import 'package:geolocator/geolocator.dart';

/// Requests location permission if needed and returns the device's current
/// GPS position. Throws a plain, user-facing [String] message on failure
/// (services off, permission denied) rather than the raw platform
/// exception. Shared by checkpoint location capture and the drop-pin
/// picker's initial position.
Future<Position> currentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw 'Turn on location services to use your current location.';
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw 'Location permission is required to use your current location.';
  }

  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );
}
