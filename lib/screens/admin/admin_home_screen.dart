import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../models/event.dart';
import '../../models/event_index.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/event_cover.dart';
import '../../widgets/shimmer_box.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_badge.dart';
import 'admin_analytics_screen.dart';
import 'event_form_screen.dart';

/// The admin's event list.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final eventService = context.read<EventService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(
            tooltip: 'Analytics',
            icon: const Icon(Icons.insights_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminAnalyticsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => context.read<AuthService>().signOut(),
          ),
          Gap.w4,
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventFormScreen(createdBy: profile.id),
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New event'),
      ),
      body: StreamBuilder<List<Event>>(
        stream: eventService.watchEvents(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(
              message: 'Could not load events',
              detail: snapshot.error,
            );
          }
          if (!snapshot.hasData) return const EventListShimmer(itemCount: 4);

          // Newest first: an admin's working set is what they just published,
          // not what happens next.
          final events = snapshot.data!.reversed.toList();
          if (events.isEmpty) {
            return const EmptyState(
              icon: Icons.event_note_outlined,
              title: 'No events yet',
              message: 'Tap "New event" to publish the first one.',
            );
          }

          return ListView.separated(
            padding: Gap.listInsets,
            itemCount: events.length,
            separatorBuilder: (_, _) => Gap.h12,
            itemBuilder: (context, index) =>
                _AdminEventTile(event: events[index], profile: profile),
          );
        },
      ),
    );
  }
}

class _AdminEventTile extends StatelessWidget {
  const _AdminEventTile({required this.event, required this.profile});

  final Event event;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final stats = context.watch<EventStatsIndex>().of(event.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: Corner.mdAll,
              child: SizedBox(
                width: 56,
                height: 56,
                child: EventCover(event: event, fallbackIconSize: 20),
              ),
            ),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall?.copyWith(fontSize: 15),
                        ),
                      ),
                      if (!event.isPublished)
                        Chip(
                          label: const Text('Draft'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  Gap.h4,
                  Text(
                    Formatters.shortDateTime.format(event.eventDate),
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Gap.h8,
                  Row(
                    children: [
                      StatusBadge(
                        status: event.statusAt(DateTime.now()),
                        dense: true,
                      ),
                      Gap.w8,
                      Icon(
                        Icons.groups_outlined,
                        size: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                      Gap.w4,
                      Text(
                        event.isLimited
                            ? '${stats.seatsTaken}/${event.capacity}'
                            : '${stats.seatsTaken}',
                        style: text.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (stats.checkedIn > 0) ...[
                        Gap.w8,
                        Icon(
                          Icons.how_to_reg_outlined,
                          size: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                        Gap.w4,
                        Text(
                          '${stats.checkedIn}',
                          style: text.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            _TileMenu(event: event, profile: profile),
          ],
        ),
      ),
    );
  }
}

/// Actions behind a menu rather than a row of icon buttons: delete sitting
/// permanently next to edit on every row is an accident waiting to happen.
class _TileMenu extends StatelessWidget {
  const _TileMenu({required this.event, required this.profile});

  final Event event;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (value) async {
        final service = context.read<EventService>();
        switch (value) {
          case 'edit':
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EventFormScreen(
                  createdBy: profile.id,
                  existingEvent: event,
                ),
              ),
            );
          case 'publish':
            await service.setPublished(
              id: event.id,
              published: !event.isPublished,
            );
          case 'delete':
            await _confirmDelete(context, service);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit'),
          ),
        ),
        PopupMenuItem(
          value: 'publish',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              event.isPublished
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            title: Text(event.isPublished ? 'Unpublish' : 'Publish'),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.delete_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    EventService service,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this event?'),
        content: Text(
          '"${event.name}" and every ticket booked for it will be removed. '
          'This cannot be undone - unpublish it instead if you only want it '
          'hidden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await service.deleteEvent(event.id);
  }
}
