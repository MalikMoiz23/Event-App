import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// A single headline number.
///
/// Follows the stat-tile contract: a sentence-case label, the value in the
/// same sans as everything else, and an optional signed delta against a named
/// period. Two details that are easy to get wrong:
///
///  * the value uses the font's **proportional** figures, not tabular - at
///    this size tabular digits give `121` the spacing of `000` and it reads
///    loose. Tabular is for columns that must align, like the bar chart's
///    value gutter;
///  * the brand colour is on the icon, not the number. A red 24pt figure on
///    every tile makes four equally urgent things, which is the same as none.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.delta,
    this.deltaIsGood,
    this.accent,
    this.onTap,
  });

  final IconData icon;
  final String value;

  /// Sentence case, no trailing colon.
  final String label;

  /// Pre-formatted and signed, e.g. `+12 this week`.
  final String? delta;

  /// Whether [delta] moving up is a good thing. Cancellations rising is not.
  final bool? deltaIsGood;

  /// Overrides the icon tint when a tile needs to stand apart, e.g. the
  /// checked-in count using the secondary series colour.
  final Color? accent;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    final tint = accent ?? scheme.primary;

    final isPositive = delta?.startsWith('-') != true;
    final good = deltaIsGood ?? true;
    final deltaColor = (isPositive == good)
        ? AppColors.resolve(
            brightness,
            AppColors.success,
            AppColors.successDark,
          )
        : AppColors.resolve(brightness, AppColors.danger, AppColors.dangerDark);

    final body = Padding(
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: Corner.smAll,
            ),
            child: Icon(icon, size: 17, color: tint),
          ),
          Gap.h12,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.headlineSmall?.copyWith(color: scheme.onSurface),
              ),
              Gap.h2,
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (delta != null) ...[
                Gap.h4,
                Row(
                  children: [
                    Icon(
                      isPositive
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 12,
                      color: deltaColor,
                    ),
                    Gap.w4,
                    Expanded(
                      child: Text(
                        delta!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelMedium?.copyWith(color: deltaColor),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );

    return Card(
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );
  }
}

/// The single number a screen leads with - one per view.
///
/// Bigger than a stat tile and without a card around it, so it reads as the
/// answer to the screen rather than one figure among four.
class HeroMetric extends StatelessWidget {
  const HeroMetric({
    super.key,
    required this.value,
    required this.label,
    this.caption,
  });

  final String value;
  final String label;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        Gap.h4,
        Text(
          value,
          style: text.displaySmall?.copyWith(
            color: scheme.onSurface,
            fontSize: 48,
          ),
        ),
        if (caption != null) ...[
          Gap.h4,
          Text(
            caption!,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
