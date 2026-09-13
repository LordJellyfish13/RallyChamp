import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'core/map/offline_cache.dart';
import 'core/notifications/notifications.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Matches app.dart's en_GB `MaterialApp` locale (Monday-first calendar):
  // without this, the calendar picker follows en_GB but every bare
  // `DateFormat.yMMMd()`-style call elsewhere in the app — there's no
  // shortage of them — would silently keep falling back to `intl`'s
  // en_US default and print "Sep 13, 2026" right next to a calendar
  // that now behaves like a European one.
  await initializeDateFormatting('en_GB');
  Intl.defaultLocale = 'en_GB';
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeMapCache();
  // Registers the notification channels only — the permission prompt comes
  // later, when following a rally gives it a reason.
  await initializeNotifications();
  runApp(const RallyChampApp());
}
