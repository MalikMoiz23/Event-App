import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/event.dart';
import '../theme/app_dimens.dart';
import '../theme/category_style.dart';

/// An event's cover image, with the placeholder and error cases handled once.
///
/// Three states used to be re-implemented at every call site: no image, image
/// loading, image failed. The fallback is the category icon on a tint rather
/// than a broken-image glyph, because an event with no photo is normal and
/// should not look like a fault.
class EventCover extends StatelessWidget {
  const EventCover({
    super.key,
    required this.event,
    this.fit = BoxFit.cover,
    this.fallbackIconSize = 44,
  });

  final Event event;
  final BoxFit fit;
  final double fallbackIconSize;

  @override
  Widget build(BuildContext context) {
    final url = event.imageUrl;
    if (url == null || url.isEmpty) return _fallback(context);

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: Motion.normal,
      placeholder: (_, _) => _placeholder(context),
      errorWidget: (_, _, _) => _fallback(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
    );
  }

  Widget _fallback(BuildContext context) {
    final tint = CategoryStyle.tintOf(
      event.category,
      Theme.of(context).brightness,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint.withValues(alpha: 0.22), tint.withValues(alpha: 0.08)],
        ),
      ),
      child: Center(
        child: Icon(
          CategoryStyle.iconOf(event.category),
          size: fallbackIconSize,
          color: tint,
        ),
      ),
    );
  }
}

/// A scrim over the bottom of a cover image so white text stays readable
/// whatever the photo underneath happens to be.
///
/// Two stops rather than a straight black fade: a linear ramp to opaque black
/// visibly greys the middle of the image, while this keeps the top two thirds
/// almost untouched.
class CoverScrim extends StatelessWidget {
  const CoverScrim({super.key, this.strength = 0.78});

  final double strength;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.45, 1.0],
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: strength * 0.25),
            Colors.black.withValues(alpha: strength),
          ],
        ),
      ),
    );
  }
}

/// The calendar-tear date block on a card: weekday, day, month stacked.
///
/// Faster to scan down a list than "Fri, 5 Sep - 7:00 pm" repeated on every
/// row, and it frees the text line underneath for the time and the venue.
class DateBlock extends StatelessWidget {
  const DateBlock({super.key, required this.date, this.onSurface = false});

  final DateTime date;

  /// Set when the block sits on a card surface rather than over an image.
  final bool onSurface;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final foreground = onSurface ? scheme.onSurface : Colors.white;
    final muted = onSurface
        ? scheme.onSurfaceVariant
        : Colors.white.withValues(alpha: 0.82);

    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      decoration: BoxDecoration(
        color: onSurface
            ? scheme.surfaceContainerHigh
            : Colors.black.withValues(alpha: 0.42),
        borderRadius: Corner.smAll,
        border: onSurface
            ? Border.all(color: scheme.outlineVariant)
            : Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _weekday(date).toUpperCase(),
            style: text.labelSmall?.copyWith(color: muted, fontSize: 9.5),
          ),
          Text(
            '${date.day}',
            style: text.titleLarge?.copyWith(
              color: foreground,
              fontSize: 20,
              height: 1.1,
            ),
          ),
          Text(
            _month(date).toUpperCase(),
            style: text.labelSmall?.copyWith(color: muted, fontSize: 9.5),
          ),
        ],
      ),
    );
  }

  // Hard-coded rather than DateFormat: this runs inside a list builder and
  // only ever needs three-letter English abbreviations.
  static String _weekday(DateTime d) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];

  static String _month(DateTime d) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][d.month - 1];
}
