import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/auth/auth_gate.dart';
import 'core/theme/app_theme.dart';

class RallyChampApp extends StatelessWidget {
  const RallyChampApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RallyChamp',
      theme: AppTheme.light,
      // en_GB rather than a translation into Croatian: the ask was the
      // Monday-first calendar convention, not a change of language, and
      // every visible string in the app is still hand-written English.
      // Flutter's date picker takes its first-day-of-week from the
      // active locale's CLDR data (`intl`'s `FIRSTDAYOFWEEK`) — en_US
      // starts Sunday, en_GB starts Monday, which is also the convention
      // the rest of Europe (Croatia included) uses.
      locale: const Locale('en', 'GB'),
      supportedLocales: const [Locale('en', 'GB')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}
