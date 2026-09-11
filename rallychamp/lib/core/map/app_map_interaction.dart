import 'package:flutter_map/flutter_map.dart';

/// Shared gesture tuning for every `FlutterMap` in the app — see
/// dev_notes.md §5 "Checkpoint GPS locations + the actual map" for why:
/// flutter_map's default twist-to-rotate gesture reads as the map
/// fighting a normal pan/pinch on a real device, and double-tap-drag-zoom
/// is easy to trigger by accident. Both dropped for a cleaner,
/// Google-Maps-like, always-north-up feel.
const appMapInteractionOptions = InteractionOptions(
  flags: InteractiveFlag.all &
      ~InteractiveFlag.rotate &
      ~InteractiveFlag.doubleTapDragZoom,
);
