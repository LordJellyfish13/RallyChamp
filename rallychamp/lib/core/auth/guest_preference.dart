import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether someone has already chosen to skip sign-in and browse
/// as a guest, so [AuthGate]'s startup login screen only appears once per
/// install rather than on every launch.
class GuestPreference {
  static const _key = 'continued_as_guest';

  static Future<bool> hasChosenGuest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> setChosenGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
