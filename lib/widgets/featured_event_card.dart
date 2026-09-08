import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../models/event.dart';
import '../theme/app_dimens.dart';
import 'event_cover.dart';
import 'favorite_heart_button.dart';
import 'status_badge.dart';

/// The large card in the Discover carousel.
///
/// This is the one place a full-bleed photo is worth the vertical space: it
/// is a shop window for three or four events, not the browsing surface. Text
/// sits over a bottom scrim so it stays legible on any photo, and the whole
/// thing is a fixed 16:10 so the carousel never jumps as images load.
class FeaturedEventCard extends StatelessWidget {
  const FeaturedEventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.width = 300,
  });

  final Event event;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final double width;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final status = event.statusAt(DateTime.now());

    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'featured-${event.id}',
                  child: EventCover(event: event, fallbackIconSize: 48),
                ),
                const CoverScrim(),
                Positioned(
                  left: Gap.md,
                  top: Gap.md,
                  child: StatusBadge(status: status, dense: true),
                ),
                if (onToggleFavorite != null)
                  Positioned(
                    right: Gap.sm,
                    top: Gap.sm,
                    child: FavoriteHeartButton(
                      isFavorite: isFavorite,
                      onToggle: onToggleFavorite!,
                    ),
                  ),
                Positioned(
                  left: Gap.lg,
                  right: Gap.lg,
                  bottom: Gap.lg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 19,
                        ),
                      ),
                      Gap.h8,
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: Colors.white70,
                          ),
                          Gap.w6,
                          Expanded(
                            child: Text(
                              Formatters.mediumDateTime.format(event.eventDate),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.88),
                              ),
                            ),
                          ),
                          Gap.w8,
                          _PricePill(event: event),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Price over a photo. Needs its own chip because a bare white price on an
/// arbitrary image is a coin toss for contrast.
class _PricePill extends StatelessWidget {
  const _PricePill({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: Corner.pillAll,
        border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 3),
        child: Text(
          Formatters.price(event.charges),
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
