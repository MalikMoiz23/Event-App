import 'package:flutter/material.dart';

/// The type scale.
///
/// Built on the platform's own UI font rather than a bundled webfont: it
/// renders at the right weight on both platforms with no download, and an
/// event listing gains nothing from a display face. What it does need is a
/// scale with real contrast between levels, tighter tracking on the large
/// sizes (Material's default looks loose above ~24px), and line heights that
/// hold up in a paragraph of event description.
class AppTypography {
  const AppTypography._();

  static TextTheme apply(TextTheme base) {
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 34,
        height: 1.15,
        letterSpacing: -0.8,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 28,
        height: 1.2,
        letterSpacing: -0.6,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 24,
        height: 1.22,
        letterSpacing: -0.4,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 20,
        height: 1.25,
        letterSpacing: -0.2,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 18,
        height: 1.3,
        letterSpacing: -0.1,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        height: 1.35,
        letterSpacing: 0,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14,
        height: 1.35,
        letterSpacing: 0.1,
        fontWeight: FontWeight.w600,
      ),
      // 1.5 line height: descriptions are the only long-form text here and
      // they are unreadable any tighter.
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12.5,
        height: 1.4,
        letterSpacing: 0.1,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        letterSpacing: 0.2,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        letterSpacing: 0.3,
        fontWeight: FontWeight.w600,
      ),
      // Wide tracking because this size is only ever used for short
      // all-caps labels - status pills, section eyebrows - where the letters
      // otherwise collide.
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  /// Tabular figures, so a column of counts or prices does not jitter as the
  /// digits change under a live stream.
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  /// The all-caps eyebrow above a section, and inside status pills.
  static TextStyle eyebrow(BuildContext context, {Color? color}) {
    return Theme.of(context).textTheme.labelSmall!.copyWith(
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  /// A headline number - a seat count, a revenue total.
  static TextStyle metric(BuildContext context, {Color? color}) {
    return Theme.of(context).textTheme.headlineSmall!.copyWith(
      color: color,
      fontFeatures: tabularFigures,
    );
  }
}
