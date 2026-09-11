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
}
