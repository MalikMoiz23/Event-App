import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../models/event.dart';
import '../theme/app_dimens.dart';
import '../theme/category_style.dart';
import 'event_cover.dart';
import 'favorite_heart_button.dart';
import 'status_badge.dart';

/// The standard event row in a vertical list.
///
/// Laid out as a horizontal band rather than a full-width photo card: at 96px
/// tall, four fit on a phone screen instead of one and a half, which is the
/// difference between browsing and scrolling. The photo still earns its place
/// as a 96px thumbnail with the date over it.
///
/// The information order is fixed - name, when, where, then price - because a
/// list is only scannable if every row answers the same questions in the same
/// place.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.seatsTaken,
    this.heroPrefix = 'event-image',
  });

  final Event event;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  /// Live booking count. When supplied and the event has a capacity, the card
  /// shows how many seats are left instead of the plain status pill.
  final int? seatsTaken;

  /// Hero tags have to be unique per screen. Two lists can show the same
  /// event at once - Saved and Discover - so the prefix separates them.
  final String heroPrefix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final status = event.statusAt(DateTime.now());
    final soldOut =
        seatsTaken != null && event.isLimited && event.isSoldOut(seatsTaken!);

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: Corner.mdAll,
                      child: Hero(
                        tag: '$heroPrefix-${event.id}',
                        child: EventCover(event: event, fallbackIconSize: 28),
                      ),
                    ),
                    Positioned(
                      left: 4,
                      top: 4,
                      child: Transform.scale(
                        scale: 0.78,
                        alignment: Alignment.topLeft,
                        child: DateBlock(date: event.eventDate),
                      ),
                    ),
                  ],
                ),
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            event.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall?.copyWith(
                              color: scheme.onSurface,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (onToggleFavorite != null) ...[
                          Gap.w4,
                          FavoriteHeartButton(
                            isFavorite: isFavorite,
                            onToggle: onToggleFavorite!,
                            onSurface: true,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                    Gap.h8,
                    _MetaLine(
                      icon: Icons.schedule_rounded,
                      label: Formatters.mediumDateTime.format(event.eventDate),
                    ),
                    if (event.venueLine != null) ...[
                      Gap.h4,
                      _MetaLine(
                        icon: Icons.place_outlined,
                        label: event.venueLine!,
                      ),
                    ],
                    Gap.h8,
                    Row(
                      children: [
                        Icon(
                          CategoryStyle.iconOf(event.category),
                          size: 13,
                          color: CategoryStyle.tintOf(
                            event.category,
                            Theme.of(context).brightness,
                          ),
                        ),
                        Gap.w4,
                        Text(
                          event.category.label,
                          style: text.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Gap.w8,
                        if (soldOut)
                          Text(
                            '• Sold out',
                            style: text.labelMedium?.copyWith(
                              color: scheme.error,
                            ),
                          )
                        else if (status == EventStatus.ongoing)
                          const StatusBadge(
                            status: EventStatus.ongoing,
                            dense: true,
                          ),
                        const Spacer(),
                        Text(
                          Formatters.price(event.charges),
                          style: text.titleSmall?.copyWith(
                            color: event.isFree
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface,
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
      ),
    );
  }
}

/// One line of secondary detail: a small muted icon and a single-line label.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 13, color: scheme.onSurfaceVariant),
        Gap.w6,
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
