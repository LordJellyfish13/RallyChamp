import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/active_rally/active_rally_cubit.dart';
import '../../../core/active_rally/active_rally_state.dart';
import '../../../core/active_rally/active_rally_switcher.dart';
import '../../../core/active_rally/no_active_rally.dart';
import '../../../core/map/app_map_interaction.dart';
import '../../../core/map/tile_downloader.dart';
import '../../../core/map/tile_math.dart';
import '../../rallies/bloc/checkpoints_cubit.dart';
import '../../rallies/bloc/checkpoints_state.dart';
import '../../rallies/bloc/stages_cubit.dart';
import '../../rallies/bloc/stages_state.dart';
import '../../rallies/data/checkpoint.dart';
import '../../rallies/data/rally_repository.dart';
import '../../rallies/data/stage.dart';

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
            if (state is ActiveRallyLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is! ActiveRallyLoaded || state.active == null) {
              return const NoActiveRally();
            }
            final rallyId = state.active!.id;
            return MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) => CheckpointsCubit(RallyRepository(), rallyId),
                ),
                BlocProvider(
                  create: (_) => StagesCubit(RallyRepository(), rallyId),
                ),
              ],
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
      builder: (context, checkpointsState) {
        if (checkpointsState is CheckpointsError) {
          return Center(
            child: Text('Could not load the map: ${checkpointsState.message}'),
          );
        }
        final checkpoints = checkpointsState is CheckpointsLoaded
            ? checkpointsState.checkpoints
                  .where((c) => c.location != null)
                  .toList()
            : const <Checkpoint>[];

        return BlocBuilder<StagesCubit, StagesState>(
          builder: (context, stagesState) {
            final stages = stagesState is StagesLoaded
                ? stagesState.stages.where((s) => s.route.length > 1).toList()
                : const <Stage>[];

            if (checkpoints.isEmpty && stages.isEmpty) {
              if (checkpointsState is CheckpointsLoading ||
                  stagesState is StagesLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    "This rally doesn't have a checkpoint location or "
                    'route set up yet.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return _RallyMap(checkpoints: checkpoints, stages: stages);
          },
        );
      },
    );
  }
}

class _RallyMap extends StatefulWidget {
  const _RallyMap({required this.checkpoints, required this.stages});

  final List<Checkpoint> checkpoints;

  /// Only stages with a real (>1 point) route — see `_RallyMapView`.
  final List<Stage> stages;

  @override
  State<_RallyMap> createState() => _RallyMapState();
}

class _RallyMapState extends State<_RallyMap> {
  var _visibleKinds = CheckpointKind.values.toSet();

  // Tracks hidden stages, not visible ones — checkpoints and stages load
  // from two independent Firestore streams, so `widget.stages` can still
  // be empty on `_RallyMap`'s first build if the stages stream just
  // hasn't delivered yet (checkpoints already had data, so the "still
  // loading" screen wasn't shown). A "visible by default" set computed
  // once up front would lock in that transient empty list forever; a
  // "hidden" set starts empty either way, so a stage is visible the
  // moment it exists, regardless of which stream won the race.
  var _hiddenStageIds = <String>{};

  IconData _iconFor(CheckpointKind kind) {
    return switch (kind) {
      CheckpointKind.viewing => Icons.visibility,
      CheckpointKind.parking => Icons.local_parking,
      CheckpointKind.box => Icons.garage,
    };
  }

  @override
  Widget build(BuildContext context) {
    final checkpoints = widget.checkpoints
        .where((c) => _visibleKinds.contains(c.kind))
        .toList();
    final stages = widget.stages
        .where((s) => !_hiddenStageIds.contains(s.id))
        .toList();

    final checkpointPoints = checkpoints
        .map((c) => LatLng(c.location!.latitude, c.location!.longitude))
        .toList();
    final allPoints = [
      ...checkpointPoints,
      for (final stage in stages) ...stage.route,
    ];

    if (allPoints.isEmpty) {
      return Stack(
        children: [
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Nothing matches the current filter.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          _FilterButton(
            visibleKinds: _visibleKinds,
            stages: widget.stages,
            hiddenStageIds: _hiddenStageIds,
            onChanged: (kinds, stageIds) => setState(() {
              _visibleKinds = kinds;
              _hiddenStageIds = stageIds;
            }),
          ),
          _DownloadOfflineButton(
            checkpoints: widget.checkpoints,
            stages: widget.stages,
          ),
        ],
      );
    }

    // CameraFit.bounds degenerates on a zero-size box (everything at one
    // distinct point — only possible here with a single checkpoint and no
    // route, since a rendered route always has >1 point) — the resulting
    // zoom comes out infinite and flutter_map silently falls back to its
    // own placeholder center (Kyiv). Center on the point directly instead.
    final MapOptions options = allPoints.length == 1
        ? MapOptions(
            initialCenter: allPoints.first,
            initialZoom: 15,
            interactionOptions: appMapInteractionOptions,
          )
        : MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(allPoints),
              padding: const EdgeInsets.all(48),
            ),
            interactionOptions: appMapInteractionOptions,
          );

    return Stack(
      children: [
        FlutterMap(
          options: options,
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.rallychamp',
            ),
            if (stages.isNotEmpty)
              PolylineLayer(
                polylines: [
                  for (final stage in stages)
                    Polyline(
                      points: stage.route,
                      color: Theme.of(context).colorScheme.primary,
                      strokeWidth: 4,
                    ),
                ],
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
                for (final stage in stages) ...[
                  Marker(
                    point: stage.route.first,
                    width: 32,
                    height: 32,
                    child: GestureDetector(
                      onTap: () => _showStageEndSnackBar(context, stage, 'Start'),
                      child: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.green,
                        child: Icon(Icons.flag, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                  Marker(
                    point: stage.route.last,
                    width: 32,
                    height: 32,
                    child: GestureDetector(
                      onTap: () =>
                          _showStageEndSnackBar(context, stage, 'Finish'),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: Theme.of(context).colorScheme.error,
                        child: const Icon(
                          Icons.sports_score,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SimpleAttributionWidget(
              source: Text('OpenStreetMap contributors'),
            ),
          ],
        ),
        _FilterButton(
          visibleKinds: _visibleKinds,
          stages: widget.stages,
          hiddenStageIds: _hiddenStageIds,
          onChanged: (kinds, stageIds) => setState(() {
            _visibleKinds = kinds;
            _hiddenStageIds = stageIds;
          }),
        ),
        _DownloadOfflineButton(
          checkpoints: widget.checkpoints,
          stages: widget.stages,
        ),
      ],
    );
  }

  void _showStageEndSnackBar(BuildContext context, Stage stage, String end) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${stage.name} — $end')));
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

/// Floating "layers" button overlaid on the map — opens a sheet to toggle
/// which checkpoint kinds are shown, plus one checkbox per stage's route
/// (each also hides that stage's Start/Finish markers). Lives on the map
/// itself rather than the AppBar so it doesn't need `MapPage`'s own state
/// to know whether there's anything to filter yet.
class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.visibleKinds,
    required this.stages,
    required this.hiddenStageIds,
    required this.onChanged,
  });

  final Set<CheckpointKind> visibleKinds;
  final List<Stage> stages;
  final Set<String> hiddenStageIds;
  final void Function(Set<CheckpointKind> kinds, Set<String> hiddenStageIds)
  onChanged;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      right: 16,
      child: FloatingActionButton.small(
        heroTag: 'mapFilter',
        tooltip: 'Filter map',
        onPressed: () => _openSheet(context),
        child: const Icon(Icons.layers_outlined),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    var kinds = Set.of(visibleKinds);
    var stageIds = Set<String>.of(hiddenStageIds);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Show on map',
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                    for (final kind in CheckpointKind.values)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(kind.label),
                        value: kinds.contains(kind),
                        onChanged: (checked) {
                          setState(() {
                            if (checked ?? false) {
                              kinds.add(kind);
                            } else {
                              kinds.remove(kind);
                            }
                          });
                          onChanged(kinds, stageIds);
                        },
                      ),
                    if (stages.isNotEmpty) ...[
                      const Divider(height: 24),
                      Text(
                        'Routes',
                        style: Theme.of(sheetContext).textTheme.labelLarge,
                      ),
                      for (final stage in stages)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(stage.name),
                          subtitle: const Text('Route + start/finish'),
                          value: !stageIds.contains(stage.id),
                          onChanged: (checked) {
                            setState(() {
                              if (checked ?? false) {
                                stageIds.remove(stage.id);
                              } else {
                                stageIds.add(stage.id);
                              }
                            });
                            onChanged(kinds, stageIds);
                          },
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Floating "download for offline use" button — pre-fetches every map tile
/// covering the rally's checkpoints and routes (the *full* set, regardless
/// of the current filter — "download for offline use" should mean the
/// whole rally, not just whatever's currently checked) so the map keeps
/// working with no signal. See dev_notes.md §5 "Offline tile caching".
class _DownloadOfflineButton extends StatelessWidget {
  const _DownloadOfflineButton({required this.checkpoints, required this.stages});

  final List<Checkpoint> checkpoints;
  final List<Stage> stages;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 72,
      right: 16,
      child: FloatingActionButton.small(
        heroTag: 'downloadOffline',
        tooltip: 'Download for offline use',
        onPressed: () => _startDownload(context),
        child: const Icon(Icons.download_for_offline_outlined),
      ),
    );
  }

  Future<void> _startDownload(BuildContext context) async {
    final points = [
      for (final checkpoint in checkpoints)
        if (checkpoint.location != null)
          LatLng(checkpoint.location!.latitude, checkpoint.location!.longitude),
      for (final stage in stages) ...stage.route,
    ];
    if (points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Nothing to download yet — add a checkpoint location or "
            'route first.',
          ),
        ),
      );
      return;
    }

    final bounds = points.length == 1
        ? LatLngBounds(points.first, points.first)
        : LatLngBounds.fromPoints(points);
    final tileCount = tilesForBounds(
      bounds,
      minZoom: offlineDownloadMinZoom,
      maxZoom: offlineDownloadMaxZoom,
    ).length;
    final estimatedMb = (tileCount * 15 / 1024).ceil();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Download for offline use?'),
        content: Text(
          'This downloads about $tileCount map tiles (roughly $estimatedMb '
          'MB) so the map keeps working with no signal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await showDialog<TileDownloadProgress>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DownloadProgressDialog(
        progressStream: downloadTilesForOfflineUse(bounds),
      ),
    );
    if (context.mounted && result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.failed == 0
                ? 'Downloaded ${result.completed} tiles for offline use.'
                : 'Downloaded ${result.completed - result.failed} tiles; '
                      '${result.failed} failed — check your connection.',
          ),
        ),
      );
    }
  }
}

class _DownloadProgressDialog extends StatefulWidget {
  const _DownloadProgressDialog({required this.progressStream});

  final Stream<TileDownloadProgress> progressStream;

  @override
  State<_DownloadProgressDialog> createState() =>
      _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  StreamSubscription<TileDownloadProgress>? _subscription;
  TileDownloadProgress? _progress;

  @override
  void initState() {
    super.initState();
    _subscription = widget.progressStream.listen((progress) {
      if (!mounted) return;
      setState(() => _progress = progress);
      if (progress.isDone) Navigator.of(context).pop(progress);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    return AlertDialog(
      title: const Text('Downloading map tiles'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: progress == null || progress.total == 0
                ? null
                : progress.completed / progress.total,
          ),
          const SizedBox(height: 12),
          Text(
            progress == null
                ? 'Starting…'
                : '${progress.completed} / ${progress.total} tiles',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_progress),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
