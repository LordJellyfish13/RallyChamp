import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hands off to whatever maps app the phone already has, rather than
/// building in-app turn-by-turn navigation ourselves — see dev_notes.md §5
/// "Map rendering". Shared by the Map tab's checkpoint sheet and the Status
/// page's on-duty assignment banner.
Future<void> openDirections(GeoPoint location) {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&destination=${location.latitude},${location.longitude}',
  );
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
