import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../theme/app_colors.dart';
import 'favorite_heart_button.dart';
import 'status_badge.dart';

class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  final Event event;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, d MMM • h:mm a');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Hero(
                  tag: 'event-image-${event.id}',
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: event.imageUrl == null
                        ? Container(
                            color: AppColors.hitRed.withValues(alpha: 0.08),
                            child: const Icon(
                              Icons.event,
                              size: 48,
                              color: AppColors.hitRed,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: event.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (_, _) => Container(color: Colors.black12),
                            errorWidget: (_, _, _) => Container(
                              color: AppColors.hitRed.withValues(alpha: 0.08),
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.hitRed,
                              ),
                            ),
                          ),
                  ),
                ),
                if (onToggleFavorite != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: FavoriteHeartButton(
                      isFavorite: isFavorite,
                      onToggle: onToggleFavorite!,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(status: event.statusAt(DateTime.now())),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dateFormat.format(event.eventDate),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Chip(
                        label: Text(event.category.label),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      const Spacer(),
                      Text(
                        event.isFree
                            ? 'Free'
                            : 'PKR ${event.charges.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(
                              color: AppColors.hitRedDark,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
