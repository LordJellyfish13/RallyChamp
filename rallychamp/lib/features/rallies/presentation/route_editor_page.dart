import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/location/current_position.dart';
import '../../../core/map/app_map_interaction.dart';
import '../bloc/stages_cubit.dart';
import '../data/stage.dart';

/// Draws or records a stage's route — see dev_notes.md §5 "Route creation":
/// tap points on the map to trace one manually, or record it live with GPS
/// while walking/driving the stage. Both add to the same working list of
/// points, saved together via "Save route". Expects a `StagesCubit` above
/// it in the tree (pushed from `StagesPage`, which already provides one).
class RouteEditorPage extends StatefulWidget {
  const RouteEditorPage({super.key, required this.stage});

  final Stage stage;

  @override
  State<RouteEditorPage> createState() => _RouteEditorPageState();
}

class _RouteEditorPageState extends State<RouteEditorPage> {
  late final List<LatLng> _route = List.of(widget.stage.route);
  StreamSubscription<Position>? _recordingSubscription;
  String? _recordingError;
  bool _saving = false;

  bool get _recording => _recordingSubscription != null;

  @override
  void dispose() {
    _recordingSubscription?.cancel();
    super.dispose();
  }

  void _addPoint(LatLng point) {
    if (_recording) return; // GPS is driving the route while recording.
    setState(() => _route.add(point));
  }

  void _undo() => setState(() => _route.removeLast());

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear route?'),
        content: const Text('This removes every point placed so far.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) setState(_route.clear);
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      await _recordingSubscription!.cancel();
      setState(() => _recordingSubscription = null);
      return;
    }

    setState(() => _recordingError = null);
    try {
      // Surfaces the permission prompt / a clear error message before
      // starting the stream — getPositionStream's own errors are less
      // friendly to show directly.
      await currentPosition();
    } catch (e) {
      setState(() => _recordingError = '$e');
      return;
    }
    if (!mounted) return;

    final subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
      ),
    ).listen(
      (position) {
        setState(
          () => _route.add(LatLng(position.latitude, position.longitude)),
        );
      },
      onError: (Object error) {
        setState(() {
          _recordingError = '$error';
          _recordingSubscription = null;
        });
      },
    );
    setState(() => _recordingSubscription = subscription);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<StagesCubit>().saveRoute(
        stageId: widget.stage.id,
        route: _route,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save route: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = !_recording && !_saving;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stage.name),
        actions: [
          IconButton(
            tooltip: 'Undo last point',
            onPressed: canEdit && _route.isNotEmpty ? _undo : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Clear route',
            onPressed: canEdit && _route.isNotEmpty ? _clear : null,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_recordingError != null)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(12),
              child: Text(
                _recordingError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              _recording
                  ? 'Recording — walk or drive the stage. '
                        '${_route.length} points so far.'
                  : 'Tap the map to add a point, or record it live with GPS.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _route.isNotEmpty
                    ? _route.first
                    : appFallbackMapCenter,
                initialZoom: _route.isNotEmpty ? 15 : 8,
                interactionOptions: appMapInteractionOptions,
                onTap: (_, point) => _addPoint(point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.rallychamp',
                ),
                if (_route.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _route,
                        color: Theme.of(context).colorScheme.primary,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (final (index, point) in _route.indexed)
                      Marker(
                        point: point,
                        width: 16,
                        height: 16,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _pointColor(context, index),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SimpleAttributionWidget(
                  source: Text('OpenStreetMap contributors'),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _toggleRecording,
                  icon: Icon(
                    _recording
                        ? Icons.stop_circle_outlined
                        : Icons.fiber_manual_record,
                  ),
                  label: Text(_recording ? 'Stop recording' : 'Record with GPS'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: canEdit && _route.length >= 2 ? _save : null,
                  icon: _saving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Save route'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _pointColor(BuildContext context, int index) {
    if (index == 0) return Colors.green;
    if (index == _route.length - 1) return Theme.of(context).colorScheme.error;
    return Theme.of(context).colorScheme.primary;
  }
}
