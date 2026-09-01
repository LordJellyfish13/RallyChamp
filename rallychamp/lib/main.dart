import 'package:flutter/material.dart';

import 'screens/main_screen.dart';

void main() {
  runApp(const RallyChamp());
}

class RallyChamp extends StatelessWidget {
  const RallyChamp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RallyChamp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
