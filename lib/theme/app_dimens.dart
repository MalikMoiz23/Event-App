import 'package:flutter/material.dart';

/// Spacing, corner and motion tokens.
///
/// Every gap in the app comes from this 4pt scale. The point is not the
/// numbers themselves but that there are only eight of them - which is what
/// stops one screen using 14 and the next 15 for the same visual gap.
class Gap {
  const Gap._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Standard horizontal page inset. Cards, headers and list rows all share
  /// it so their left edges line up down the screen.
  static const double page = 20;

  static const SizedBox h2 = SizedBox(height: xxs);
  static const SizedBox h4 = SizedBox(height: xs);
  static const SizedBox h8 = SizedBox(height: sm);
  static const SizedBox h12 = SizedBox(height: md);
  static const SizedBox h16 = SizedBox(height: lg);
  static const SizedBox h20 = SizedBox(height: xl);
  static const SizedBox h24 = SizedBox(height: xxl);
  static const SizedBox h32 = SizedBox(height: xxxl);

  static const SizedBox w4 = SizedBox(width: xs);
  static const SizedBox w6 = SizedBox(width: 6);
  static const SizedBox w8 = SizedBox(width: sm);
  static const SizedBox w12 = SizedBox(width: md);
  static const SizedBox w16 = SizedBox(width: lg);

  static const EdgeInsets pageInsets = EdgeInsets.symmetric(horizontal: page);

  /// Bottom padding for a scroll view sitting behind the navigation bar, so
  /// the last card is not trapped underneath it.
  static const EdgeInsets listInsets = EdgeInsets.only(
    left: page,
    right: page,
    top: md,
    bottom: 96,
  );
}

/// Corner radii. Larger shapes get larger radii, otherwise a big card looks
/// sharp next to a small chip with the same corner.
class Corner {
  const Corner._();

  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  /// Sheet corners: rounded at the top, square where it meets the screen edge.
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}

/// Animation durations and curves.
///
/// Three speeds, not fifteen: [quick] for a state flip the finger is already
/// on, [normal] for something entering or leaving, [slow] for a value the eye
/// is meant to follow, like a bar growing.
class Motion {
  const Motion._();

  static const Duration quick = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 620);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasis = Curves.easeOutBack;
}
