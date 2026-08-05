import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BarChartEntry {
  const BarChartEntry({required this.label, required this.value});

  final String label;
  final num value;
}

/// A minimal single-series bar chart: one brand-color hue (magnitude is
/// carried by height, not color), rounded data-ends, a direct value label
/// per bar (acceptable at this scale - at most a handful of bars), and a
/// short category label underneath. No legend - a single series needs none.
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({super.key, required this.entries, this.height = 180});

  final List<BarChartEntry> entries;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxValue = entries
        .map((e) => e.value)
        .fold<num>(0, (a, b) => a > b ? a : b);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final entry in entries)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  children: [
                    Text(
                      '${entry.value}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: maxValue == 0 ? 0.0 : entry.value / maxValue,
                        ),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, _) {
                          return Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: t <= 0 ? 0.01 : t,
                              widthFactor: 1,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: AppColors.hitRed,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
