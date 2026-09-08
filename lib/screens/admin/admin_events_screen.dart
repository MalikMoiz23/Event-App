import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../models/event.dart';
import '../../models/event_index.dart';
import '../../models/user_profile.dart';
import '../../services/event_service.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/capacity_meter.dart';
import '../../widgets/event_cover.dart';
import '../../widgets/shimmer_box.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_badge.dart';
import 'attendee_roster_screen.dart';
import 'event_form_screen.dart';

/// The admin's working list.
///
/// Ordered newest first, not soonest first: an admin's working set is what
/// they just published, whereas an attendee's is what happens next. Drafts
/// are in the same list rather than a separate tab, because a draft is a
/// half-finished item of work and hiding it is how it gets forgotten.
class AdminEventsScreen extends StatelessWidget {
  const AdminEventsScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
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
        stream: context.read<EventService>().watchEvents(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(
              message: 'Could not load events',
              detail: snapshot.error,
            );
          }
          if (!snapshot.hasData) return const EventListShimmer(itemCount: 4);

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
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AttendeeRosterScreen(event: event)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            children: [
              Row(
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
                            _Count(
                              icon: Icons.groups_outlined,
                              label: event.isLimited
                                  ? '${stats.seatsTaken}/${event.capacity}'
                                  : '${stats.seatsTaken}',
                            ),
                            if (stats.checkedIn > 0) ...[
                              Gap.w8,
                              _Count(
                                icon: Icons.how_to_reg_outlined,
                                label: '${stats.checkedIn}',
                              ),
                            ],
                            if (stats.waitlisted > 0) ...[
                              Gap.w8,
                              _Count(
                                icon: Icons.hourglass_top_outlined,
                                label: '${stats.waitlisted}',
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
              // Only worth the row when there is a limit to be close to.
              if (event.isLimited) ...[
                Gap.h12,
                CapacityMeter(
                  seatsTaken: stats.seatsTaken,
                  capacity: event.capacity!,
                  waitlisted: stats.waitlisted,
                  showCaption: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: scheme.onSurfaceVariant),
        Gap.w4,
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
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
        final navigator = Navigator.of(context);
        switch (value) {
          case 'roster':
            navigator.push(
              MaterialPageRoute(
                builder: (_) => AttendeeRosterScreen(event: event),
              ),
            );
          case 'edit':
            navigator.push(
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
          value: 'roster',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.groups_outlined),
            title: Text('Attendees'),
          ),
        ),
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
