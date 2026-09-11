import 'package:shared_preferences/shared_preferences.dart';

/// Rally ids this device has followed (as a spectator) or applied to
/// (marshal/judge/team), most-recently-active first. Purely local/device
/// state — like `GuestPreference`, not tied to a Firebase account, since
/// following a rally works for guests too. Drives what `ActiveRallyCubit`
/// shows on the Map/Status/Results tabs.
class MyRalliesStore {
  static const _key = 'my_rally_ids';

  static Future<List<String>> rallyIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  /// Marks [rallyId] as the most recently active one — moves it to the
  /// front of the list, inserting it if it wasn't already there. Call this
  /// after a successful follow/application, and when someone picks a
  /// different rally from the switcher.
  static Future<void> recordVisit(String rallyId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key) ?? <String>[];
    ids.remove(rallyId);
    ids.insert(0, rallyId);
    await prefs.setStringList(_key, ids);
  }
}
