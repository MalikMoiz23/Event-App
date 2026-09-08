import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../theme/app_dimens.dart';

class BarChartEntry {
  const BarChartEntry({required this.label, required this.value, this.onTap});

  final String label;
  final num value;

  /// Mobile's stand-in for hover: tapping a bar opens the thing it stands for.
  final VoidCallback? onTap;
}

/// A single-series magnitude comparison, drawn as horizontal bars.
///
/// Horizontal, not vertical, because the categories are event names: as
/// columns they need rotated or truncated labels, whereas as rows each name
/// gets a full line of readable left-aligned text.
///
/// Deliberately absent:
///
///  * **No legend.** One series, so the section title already names it; a box
///    with a single swatch would just restate the heading.
///  * **No gridlines or value axis.** Every bar is directly labelled, which
///    is more precise than reading a position against a tick, and the ticks
///    would then be redundant ink.
///  * **No colour encoding.** Magnitude is carried by length. Painting each
///    bar a different hue would imply the colours mean something.
class HorizontalBarChart extends StatelessWidget {
  const HorizontalBarChart({
    super.key,
    required this.entries,
    this.barColor,
    this.maxLabelWidth = 116,
  });

  final List<BarChartEntry> entries;

  /// Defaults to the theme's primary.
  final Color? barColor;
  final double maxLabelWidth;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fill = barColor ?? scheme.primary;

    final peak = entries
        .map((e) => e.value)
        .fold<num>(0, (a, b) => a > b ? a : b);

    return Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          // A 2px surface gap is what separates touching marks; these rows
          // are already further apart than that for the label to breathe.
          if (i > 0) Gap.h12,
          _Bar(
            entry: entries[i],
            // Longest bar fills the track; the rest are relative to it. An
            // absolute scale would leave every bar stubby whenever one event
            // runs away with the bookings.
            fraction: peak == 0 ? 0 : entries[i].value / peak,
            fill: fill,
            labelWidth: maxLabelWidth,
            labelStyle: text.bodySmall!.copyWith(color: scheme.onSurface),
            valueStyle: text.labelMedium!.copyWith(
              color: scheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            trackColor: scheme.surfaceContainerHigh,
            // 620ms staggered by row, so the eye can follow the bars growing
            // instead of the whole chart snapping into place.
            delay: Duration(milliseconds: 40 * i),
          ),
        ],
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.entry,
    required this.fraction,
    required this.fill,
    required this.labelWidth,
    required this.labelStyle,
    required this.valueStyle,
    required this.trackColor,
    required this.delay,
  });

  final BarChartEntry entry;
  final num fraction;
  final Color fill;
  final double labelWidth;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final Color trackColor;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final bar = Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            entry.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        ),
        Gap.w12,
        Expanded(
          child: ClipRRect(
            // 4px rounded data-end, square where it meets the baseline on the
            // left, so the bar reads as growing from the axis.
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
            child: Container(
              height: 14,
              color: trackColor,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction.toDouble()),
                duration: Motion.slow,
                curve: Motion.enter,
                builder: (context, value, _) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      // A zero-value bar still shows a sliver, otherwise the
                      // row looks like missing data rather than a real zero.
                      widthFactor: value <= 0 ? 0.008 : value,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Gap.w12,
        // Fixed column so the numbers line up down the chart and no label
        // ever has to be clipped into its own bar.
        SizedBox(
          width: 40,
          child: Text(
            Formatters.count(entry.value),
            textAlign: TextAlign.right,
            style: valueStyle,
          ),
        ),
      ],
    );

    if (entry.onTap == null) return bar;
    return InkWell(
      onTap: entry.onTap,
      borderRadius: Corner.smAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.xs),
        child: bar,
      ),
    );
  }
}
