import 'package:flutter/material.dart';
import '../models/event.dart';
import '../theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final EventStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      EventStatus.upcoming => ('UPCOMING', AppColors.statusUpcoming),
      EventStatus.ongoing => ('ONGOING', AppColors.statusOngoing),
      EventStatus.past => ('PAST', AppColors.statusPast),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
