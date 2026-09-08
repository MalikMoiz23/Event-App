import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// How full an event is.
///
/// A meter, not a chart: one value against a known maximum. The fill carries
/// severity - accent while there is room, warning as it tightens, danger when
/// it is nearly gone - and the empty track is a lighter step of whatever hue
/// the fill currently is, so the state reads across the whole bar rather than
/// only from the filled part.
///
/// Severity here is the attendee's, not the organiser's: an event at 95% is
/// good news for the organiser and urgent for the person still deciding.
class CapacityMeter extends StatelessWidget {
  const CapacityMeter({
    super.key,
    required this.seatsTaken,
    required this.capacity,
    this.waitlisted = 0,
    this.showCaption = true,
  });

  final int seatsTaken;
  final int capacity;
  final int waitlisted;
  final bool showCaption;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;

    final ratio = capacity <= 0 ? 1.0 : (seatsTaken / capacity).clamp(0.0, 1.0);
    final left = (capacity - seatsTaken).clamp(0, capacity);
    final soldOut = left <= 0;

    final fill = switch (ratio) {
      >= 0.95 => AppColors.resolve(
        brightness,
        AppColors.danger,
        AppColors.dangerDark,
      ),
      >= 0.75 => AppColors.resolve(
        brightness,
        AppColors.warning,
        AppColors.warningDark,
      ),
      _ => AppColors.resolve(brightness, AppColors.teal, AppColors.tealBright),
    };

    final caption = soldOut
        ? (waitlisted > 0
              ? 'Sold out • ${Formatters.count(waitlisted)} on the waitlist'
              : 'Sold out • join the waitlist')
        : '${Formatters.count(left)} of ${Formatters.count(capacity)} seats left';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: Corner.pillAll,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: Motion.slow,
            curve: Motion.enter,
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: fill.withValues(alpha: 0.16),
                valueColor: AlwaysStoppedAnimation(fill),
              );
            },
          ),
        ),
        if (showCaption) ...[
          Gap.h8,
          Row(
            children: [
              Icon(
                soldOut
                    ? Icons.do_not_disturb_on_rounded
                    : Icons.event_seat_rounded,
                size: 14,
                color: fill,
              ),
              Gap.w6,
              // Text stays in an ink token; the coloured icon beside it is
              // what carries the state.
              Expanded(
                child: Text(
                  caption,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
