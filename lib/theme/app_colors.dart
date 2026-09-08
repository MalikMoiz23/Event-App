import 'package:flutter/material.dart';

/// The brand palette, plus the neutral ramp the surfaces are built from.
///
/// Only two of these are brand colours. Everything else is deliberately
/// desaturated: HIT red is a heavy colour, and an interface that paints it on
/// every bar and heading reads as a template. Here it is reserved for primary
/// actions, the current selection, and the single most important number on a
/// screen - so that when it does appear, it means something.
class AppColors {
  const AppColors._();

  /// From the HIT (Heavy Industries Taxila) crest.
  static const Color hitRed = Color(0xFFC8102E);
  static const Color hitRedDark = Color(0xFF8E0B20);

  /// Lifted a little for dark surfaces, where the crest red sits too close to
  /// the background to carry a filled button.
  static const Color hitRedBright = Color(0xFFE83A52);

  /// Supporting accent. Used where red would be a lie - a second data series,
  /// a "checked in" tally - and picked to stay distinguishable from red for
  /// the most common form of colour blindness.
  // Both steps validated against their own surface, not flipped from each
  // other: light #0A9396 on white, dark #12A79A on the dark ground. Worst-case
  // CVD separation from the brand red is deltaE 14.2 and 10.4 respectively.
  static const Color teal = Color(0xFF0A9396);
  static const Color tealBright = Color(0xFF12A79A);

  // Warm neutrals. A neutral grey next to this red looks cold, so the ramp
  // carries a few points of red in it.
  static const Color ink = Color(0xFF191516);
  static const Color inkMuted = Color(0xFF5D5657);
  static const Color canvas = Color(0xFFFAF8F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF4F1F0);
  static const Color surfaceAltHigh = Color(0xFFEDE9E8);
  static const Color hairline = Color(0xFFE4DEDD);
  static const Color border = Color(0xFFC9C1C0);

  static const Color darkCanvas = Color(0xFF0F0D0E);
  static const Color darkSurface = Color(0xFF161314);
  static const Color darkSurfaceAlt = Color(0xFF1E1A1B);
  static const Color darkSurfaceAltHigh = Color(0xFF272223);
  static const Color darkHairline = Color(0xFF322C2D);
  static const Color darkBorder = Color(0xFF4A4243);
  static const Color darkInk = Color(0xFFF3EFEE);
  static const Color darkInkMuted = Color(0xFFA79E9F);

  // Event lifecycle. Blue reads as "scheduled", green as "live", grey as
  // "over" - and none of them is the brand red, so a status pill never
  // competes with a call to action.
  static const Color statusUpcoming = Color(0xFF1D5FBF);
  static const Color statusOngoing = Color(0xFF1B7F3B);
  static const Color statusPast = Color(0xFF6E6768);

  static const Color statusUpcomingDark = Color(0xFF7FADF5);
  static const Color statusOngoingDark = Color(0xFF57C97D);
  static const Color statusPastDark = Color(0xFF9A9394);

  // Ticket lifecycle.
  static const Color success = Color(0xFF1B7F3B);
  static const Color successDark = Color(0xFF57C97D);
  static const Color warning = Color(0xFFB4690E);
  static const Color warningDark = Color(0xFFF0A33C);
  static const Color danger = Color(0xFFB3261E);
  static const Color dangerDark = Color(0xFFF28C85);

  /// Picks the light or dark variant of a semantic colour for [brightness].
  static Color resolve(Brightness brightness, Color light, Color dark) =>
      brightness == Brightness.light ? light : dark;
}
