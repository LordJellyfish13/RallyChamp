import 'package:url_launcher/url_launcher.dart';

/// Hands a number to the phone's own dialer. Deliberately a `tel:` deep
/// link rather than in-app calling (dev_notes.md §5): it's free, and a
/// normal cellular voice call often works on signal far too weak to carry
/// a data connection — which is exactly the situation this gets used in.
Future<void> callNumber(String phoneNumber) {
  return launchUrl(Uri(scheme: 'tel', path: phoneNumber));
}
