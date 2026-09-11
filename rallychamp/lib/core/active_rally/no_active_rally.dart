import 'package:flutter/material.dart';

/// Shared empty state for the Map/Status/Results tabs when nobody's
/// followed or applied to a rally on this device yet.
class NoActiveRally extends StatelessWidget {
  const NoActiveRally({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          "You're not following or applied to a rally yet. Follow one from "
          'the News tab to see it here.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
