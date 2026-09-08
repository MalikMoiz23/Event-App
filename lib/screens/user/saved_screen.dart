import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/event.dart';
import '../../models/event_index.dart';
import '../../models/user_profile.dart';
import '../../services/event_service.dart';
import '../../services/favorite_service.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/event_card.dart';
import '../../widgets/shimmer_box.dart';
import '../../widgets/state_views.dart';
import 'event_detail_screen.dart';

/// Saved events.
///
/// Sorted with the soonest first and finished ones pushed to the bottom: a
/// saved list is a shortlist of things still to decide on, so an event that
/// has already happened should not sit at the top of it.
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoriteIndex>();
    final stats = context.watch<EventStatsIndex>();
    final favoriteService = context.read<FavoriteService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved'),
        actions: [
          if (favorites.count > 0)
            Padding(
              padding: const EdgeInsets.only(right: Gap.lg),
              child: Center(
                child: Text(
                  '${favorites.count}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: StreamBuilder<List<Event>>(
        stream: context.read<EventService>().watchEvents(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(
              message: 'Could not load your saved events',
              detail: snapshot.error,
            );
          }
          if (!snapshot.hasData) return const EventListShimmer(itemCount: 3);

          final now = DateTime.now();
          final saved =
              snapshot.data!.where((e) => favorites.contains(e.id)).toList()
                ..sort((a, b) {
                  final aOver = a.endDate.isBefore(now);
                  final bOver = b.endDate.isBefore(now);
                  if (aOver != bOver) return aOver ? 1 : -1;
                  return a.eventDate.compareTo(b.eventDate);
                });

          if (saved.isEmpty) {
            return const EmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'Nothing saved yet',
              message:
                  'Tap the heart on any event to keep it here while you decide.',
            );
          }

          return ListView.separated(
            padding: Gap.listInsets,
            itemCount: saved.length,
            separatorBuilder: (_, _) => Gap.h12,
            itemBuilder: (context, index) {
              final event = saved[index];
              return EventCard(
                event: event,
                heroPrefix: 'saved',
                seatsTaken: stats.seatsTakenOf(event.id),
                isFavorite: true,
                onToggleFavorite: () => favoriteService.setFavorite(
                  eventId: event.id,
                  userId: profile.id,
                  favorited: false,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EventDetailScreen(
                      event: event,
                      profile: profile,
                      heroPrefix: 'saved',
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
