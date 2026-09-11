import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/location/current_position.dart';
import '../../../core/map/app_map_interaction.dart';

/// Croatia's rough center — used only as a last-resort starting point when
/// GPS isn't available (services off, permission denied); the pin is
/// freely draggable afterwards regardless, so this never blocks anyone.
const _fallbackCenter = LatLng(45.1, 15.2);

/// Lets someone place a checkpoint (or, later, a route point) by panning
/// the map under a fixed center pin, Google-Maps-picker style, rather than
/// standing at the spot with GPS. A secondary option next to "use current
/// location" — see dev_notes.md §5 "Checkpoint GPS locations + the actual
/// map". Pops the confirmed [GeoPoint], or null if cancelled.
class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key, this.initialLocation});

  /// Where to start the pin — an already-captured location when editing,
  /// otherwise null to start from the device's current GPS position (or
  /// [_fallbackCenter] if that's unavailable).
  final GeoPoint? initialLocation;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  late LatLng _center = widget.initialLocation == null
      ? _fallbackCenter
      : LatLng(widget.initialLocation!.latitude, widget.initialLocation!.longitude);
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation == null) _centerOnCurrentLocation();
  }

  Future<void> _centerOnCurrentLocation() async {
    try {
      final position = await currentPosition();
      if (!mounted) return;
      final here = LatLng(position.latitude, position.longitude);
      setState(() => _center = here);
      _mapController.move(here, 15);
    } catch (_) {
      // Fine to just stay on the fallback center — the pin is freely
      // draggable either way.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drop pin'),
        actions: [
          IconButton(
            tooltip: 'Use current location',
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnCurrentLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15,
              interactionOptions: appMapInteractionOptions,
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) _center = camera.center;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.rallychamp',
              ),
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap contributors'),
              ),
            ],
          ),
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -18),
                child: Icon(
                  Icons.location_pin,
                  size: 44,
                  color: Theme.of(context).colorScheme.primary,
                  shadows: const [
                    Shadow(color: Colors.black38, blurRadius: 4),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).pop(GeoPoint(_center.latitude, _center.longitude)),
            icon: const Icon(Icons.check),
            label: const Text('Confirm location'),
          ),
        ),
      ),
    );
  }
}
