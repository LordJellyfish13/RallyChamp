import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/active_rally/active_rally_cubit.dart';
import '../../../core/map/app_map_interaction.dart';
import '../../../core/active_rally/active_rally_state.dart';
import '../../../core/active_rally/active_rally_switcher.dart';
import '../../../core/active_rally/no_active_rally.dart';
import '../../rallies/bloc/checkpoints_cubit.dart';
import '../../rallies/bloc/checkpoints_state.dart';
import '../../rallies/data/checkpoint.dart';
import '../../rallies/data/rally_repository.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ActiveRallyCubit(RallyRepository()),
      child: Scaffold(
        appBar: AppBar(title: const ActiveRallySwitcher(fallbackTitle: 'Map')),
        body: BlocBuilder<ActiveRallyCubit, ActiveRallyState>(
          builder: (context, state) {
            if (state is! ActiveRallyLoaded || state.active == null) {
              return const NoActiveRally();
            }
            return BlocProvider(
              create: (_) =>
                  CheckpointsCubit(RallyRepository(), state.active!.id),
              child: const _RallyMapView(),
            );
          },
        ),
      ),
    );
  }
}

class _RallyMapView extends StatelessWidget {
  const _RallyMapView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CheckpointsCubit, CheckpointsState>(
      builder: (context, state) {
        switch (state) {
          case CheckpointsLoading():
            return const Center(child: CircularProgressIndicator());
          case CheckpointsError(:final message):
            return Center(child: Text('Could not load the map: $message'));
          case CheckpointsLoaded(:final checkpoints):
            final located = checkpoints
                .where((c) => c.location != null)
                .toList();
            if (located.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    "This rally's checkpoints don't have a location set "
                    'yet. The organizer can add one from the Checkpoints '
                    'page.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return _CheckpointsMap(checkpoints: located);
        }
      },
    );
  }
}

class _CheckpointsMap extends StatelessWidget {
  const _CheckpointsMap({required this.checkpoints});

  final List<Checkpoint> checkpoints;

  IconData _iconFor(CheckpointKind kind) {
    return switch (kind) {
      CheckpointKind.viewing => Icons.visibility,
      CheckpointKind.parking => Icons.local_parking,
      CheckpointKind.box => Icons.garage,
    };
  }

  @override
  Widget build(BuildContext context) {
    final points = checkpoints
        .map((c) => LatLng(c.location!.latitude, c.location!.longitude))
        .toList();

    // CameraFit.bounds degenerates on a zero-size box (a single checkpoint,
    // or several at the same spot) — the resulting zoom comes out infinite
    // and flutter_map silently falls back to its own placeholder center
    // (Kyiv). Center on the point directly instead whenever there's only
    // one distinct location to show.
    final MapOptions options = points.length == 1
        ? MapOptions(
            initialCenter: points.first,
            initialZoom: 15,
            interactionOptions: appMapInteractionOptions,
          )
        : MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.all(48),
            ),
            interactionOptions: appMapInteractionOptions,
          );

    return FlutterMap(
      options: options,
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.rallychamp',
        ),
        MarkerLayer(
          markers: [
            for (final checkpoint in checkpoints)
              Marker(
                point: LatLng(
                  checkpoint.location!.latitude,
                  checkpoint.location!.longitude,
                ),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () => _showCheckpointSheet(context, checkpoint),
                  child: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Icon(
                      _iconFor(checkpoint.kind),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SimpleAttributionWidget(
          source: Text('OpenStreetMap contributors'),
        ),
      ],
    );
  }

  void _showCheckpointSheet(BuildContext context, Checkpoint checkpoint) {
    final color = Theme.of(context).colorScheme.primary;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: color,
                      child: Icon(
                        _iconFor(checkpoint.kind),
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            checkpoint.code,
                            style: Theme.of(sheetContext).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Chip(
                            label: Text(checkpoint.kind.label),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openDirections(checkpoint),
                    icon: const Icon(Icons.directions),
                    label: const Text('Get directions'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDirections(Checkpoint checkpoint) {
    final location = checkpoint.location!;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${location.latitude},${location.longitude}',
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
