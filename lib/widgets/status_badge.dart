import 'package:flutter/material.dart';

import '../models/event.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// A small state pill: event lifecycle, or ticket lifecycle.
///
/// Tinted rather than filled. A row of solid colour blocks on a card competes
/// with the cover image and the price for attention, and there are often two
/// of these side by side. State is carried by an icon and a word as well as
/// by hue, so it survives colour blindness and a greyscale screenshot.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.dense = false});

  final EventStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final (label, color, icon) = switch (status) {
      EventStatus.upcoming => (
        'Upcoming',
        AppColors.resolve(
          brightness,
          AppColors.statusUpcoming,
          AppColors.statusUpcomingDark,
        ),
        Icons.schedule_rounded,
      ),
      EventStatus.ongoing => (
        'Live now',
        AppColors.resolve(
          brightness,
          AppColors.statusOngoing,
          AppColors.statusOngoingDark,
        ),
        Icons.sensors_rounded,
      ),
      EventStatus.past => (
        'Finished',
        AppColors.resolve(
          brightness,
          AppColors.statusPast,
          AppColors.statusPastDark,
        ),
        Icons.check_rounded,
      ),
    };

    return _Pill(label: label, color: color, icon: icon, dense: dense);
  }
}

class TicketStatusBadge extends StatelessWidget {
  const TicketStatusBadge({
    super.key,
    required this.status,
    this.dense = false,
  });

  final TicketStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final (color, icon) = switch (status) {
      TicketStatus.confirmed => (
        AppColors.resolve(brightness, AppColors.success, AppColors.successDark),
        Icons.confirmation_number_rounded,
      ),
      TicketStatus.checkedIn => (
        AppColors.resolve(brightness, AppColors.teal, AppColors.tealBright),
        Icons.how_to_reg_rounded,
      ),
      TicketStatus.waitlisted => (
        AppColors.resolve(brightness, AppColors.warning, AppColors.warningDark),
        Icons.hourglass_top_rounded,
      ),
      TicketStatus.cancelled => (
        AppColors.resolve(brightness, AppColors.danger, AppColors.dangerDark),
        Icons.cancel_rounded,
      ),
    };

    return _Pill(label: status.label, color: color, icon: icon, dense: dense);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.icon,
    required this.dense,
  });

  final String label;
  final Color color;
  final IconData icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: Corner.pillAll,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? Gap.sm : Gap.md,
          vertical: dense ? 3 : 5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: dense ? 11 : 13, color: color),
            SizedBox(width: dense ? 3 : 5),
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontSize: dense ? 9.5 : 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
