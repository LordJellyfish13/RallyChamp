import 'package:flutter/material.dart';

import 'core/navigation/main_screen.dart';
import 'core/theme/app_theme.dart';

class RallyChampApp extends StatelessWidget {
  const RallyChampApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RallyChamp',
      theme: AppTheme.light,
      home: const MainScreen(),
    );
  }
}
