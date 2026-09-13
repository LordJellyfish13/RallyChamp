import 'package:flutter/material.dart';

/// The RallyChamp palette. See dev_notes.md §5 "Visual design direction"
/// for where these values come from and why.
class AppColors {
  AppColors._();

  static const bg = Color(0xFFFBF5EF);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFE8DDD2);
  static const ink = Color(0xFF1E1712);
  static const inkSoft = Color(0xFF5A5049);
  static const charcoal = Color(0xFF211914);

  /// For badges, borders and small accents — not for white text on top of
  /// it (fails WCAG contrast). Use [primaryStrong] for that.
  static const primary = Color(0xFFF1571C);

  /// For filled buttons and icons carrying white text/foreground.
  static const primaryStrong = Color(0xFFC8420E);

  /// Text color on [primaryTint] backgrounds (badges, tonal buttons).
  static const primaryDark = Color(0xFFA61B29);
  static const primaryTint = Color(0xFFFDE6DB);

  /// General danger/validation red — distinct from the rally-status color
  /// system (not built yet; see dev_notes.md when the Status page is real).
  static const error = Color(0xFFB3211A);

  /// Reused for "success"/"resolved"/"published"-type affordances outside
  /// the not-yet-built rally-status system.
  static const success = Color(0xFF1F7A44);
  static const successTint = Color(0xFFE1F1E6);

  /// For neutral states like "draft" — not urgent, not positive/negative.
  static const neutralTint = Color(0xFFEBE7E2);

  // ---------------------------------------------------------------------
  // Rally status colors. Designed and contrast-checked in the design canvas
  // (see dev_notes.md §5 "Visual design direction"), deliberately kept
  // distinct from each other and from the brand orange/red. Built now
  // rather than earlier because nothing consumed them until the Status
  // page became real — exactly the trigger dev_notes named.
  //
  // `base` is the saturated form, for solid fills carrying white text or
  // icons. `text` is the darker, text-safe form for small text on that
  // status's own `tint` — the same hue usually can't do both and still
  // clear WCAG AA, which is why there are three tokens and not one.
  // ---------------------------------------------------------------------

  static const statusSetup = Color(0xFF6B7280);
  static const statusSetupTint = Color(0xFFEAEBED);
  static const statusSetupText = Color(0xFF52585F);

  static const statusRunning = Color(0xFF2F9E5B);
  static const statusRunningTint = Color(0xFFE1F1E6);
  static const statusRunningText = Color(0xFF1F7A44);

  static const statusPaused = Color(0xFFD9A22B);
  static const statusPausedTint = Color(0xFFFAF0DA);
  static const statusPausedText = Color(0xFF8A6410);

  static const statusLunch = Color(0xFF7B5EA7);
  static const statusLunchTint = Color(0xFFEFE7F5);
  static const statusLunchText = Color(0xFF5B3E82);

  static const statusStopped = Color(0xFFB3211A);
  static const statusStoppedTint = Color(0xFFF7E0DE);
  static const statusStoppedText = Color(0xFFB3211A);

  static const statusFinished = Color(0xFF2E6FA3);
  static const statusFinishedTint = Color(0xFFE4EEF6);
  static const statusFinishedText = Color(0xFF2E6FA3);
}

/// One status's three-color set. A lookup rather than switch statements
/// scattered through widgets — dev_notes.md §5 called this shape out
/// specifically when the palette was deferred.
class StatusColors {
  const StatusColors({
    required this.base,
    required this.tint,
    required this.text,
  });

  final Color base;
  final Color tint;
  final Color text;

  static const setup = StatusColors(
    base: AppColors.statusSetup,
    tint: AppColors.statusSetupTint,
    text: AppColors.statusSetupText,
  );
  static const running = StatusColors(
    base: AppColors.statusRunning,
    tint: AppColors.statusRunningTint,
    text: AppColors.statusRunningText,
  );
  static const paused = StatusColors(
    base: AppColors.statusPaused,
    tint: AppColors.statusPausedTint,
    text: AppColors.statusPausedText,
  );
  static const lunch = StatusColors(
    base: AppColors.statusLunch,
    tint: AppColors.statusLunchTint,
    text: AppColors.statusLunchText,
  );
  static const stopped = StatusColors(
    base: AppColors.statusStopped,
    tint: AppColors.statusStoppedTint,
    text: AppColors.statusStoppedText,
  );
  static const finished = StatusColors(
    base: AppColors.statusFinished,
    tint: AppColors.statusFinishedTint,
    text: AppColors.statusFinishedText,
  );

  /// 'start' shares the running palette — it's already "the rally is
  /// happening" as far as anyone reading a color is concerned, and giving
  /// it a seventh hue would dilute the system for no gain.
  ///
  /// 'stopped' deliberately renders in the blue [finished] palette rather
  /// than the red [stopped] one: a rally ending normally is not an
  /// emergency, and once incident alerts share this feed (v2), red has to
  /// mean "something is wrong" or it stops meaning anything at all. The
  /// red tokens still exist — they're what danger-severity events use.
  static StatusColors forRallyStatus(String status) => switch (status) {
    'running' || 'start' => running,
    'paused' => paused,
    'lunch break' => lunch,
    'stopped' => finished,
    _ => setup,
  };
}
