import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/event.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/rsvp_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/hit_logo.dart';
import '../../widgets/shimmer_box.dart';
import '../../widgets/staggered_fade_slide.dart';
import '../../widgets/status_badge.dart';
import 'admin_analytics_screen.dart';
import 'event_form_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({
    super.key,
    required this.profile,
    required this.eventService,
    required this.authService,
    required this.rsvpService,
  });

  final UserProfile profile;
  final EventService eventService;
  final AuthService authService;
  final RsvpService rsvpService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HitLogo(size: 32),
            const SizedBox(width: 10),
            const Text('HIT EVO • Admin'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Analytics',
            icon: const Icon(Icons.bar_chart_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AdminAnalyticsScreen(
                  eventService: eventService,
                  rsvpService: rsvpService,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => authService.signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventFormScreen(
              eventService: eventService,
              createdBy: profile.id,
            ),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Event'),
      ),
      body: StreamBuilder<List<Event>>(
        stream: eventService.watchEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const EventListShimmer();
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load events: ${snapshot.error}'));
          }
          final events = (snapshot.data ?? []).reversed.toList();
          if (events.isEmpty) {
            return const Center(
              child: Text('No events yet. Tap "New Event" to publish one.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 88),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return StaggeredFadeSlide(
                index: index,
                child: _AdminEventTile(
                  event: event,
                  rsvpService: rsvpService,
                  onEdit: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EventFormScreen(
                        eventService: eventService,
                        createdBy: profile.id,
                        existingEvent: event,
                      ),
                    ),
                  ),
                  onDelete: () => _confirmDelete(context, event),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text('This will permanently remove "${event.name}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await eventService.deleteEvent(event.id);
    }
  }
}

class _AdminEventTile extends StatelessWidget {
  const _AdminEventTile({
    required this.event,
    required this.rsvpService,
    required this.onEdit,
    required this.onDelete,
  });

  final Event event;
  final RsvpService rsvpService;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM, h:mm a');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.hitRed.withValues(alpha: 0.1),
          backgroundImage: event.imageUrl != null
              ? NetworkImage(event.imageUrl!)
              : null,
          child: event.imageUrl == null
              ? const Icon(Icons.event, color: AppColors.hitRed)
              : null,
        ),
        title: Text(event.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${dateFormat.format(event.eventDate)} • ${event.category.label}'),
            const SizedBox(height: 6),
            Row(
              children: [
                StatusBadge(status: event.statusAt(DateTime.now())),
                const SizedBox(width: 8),
                StreamBuilder<List<String>>(
                  stream: rsvpService.watchAttendees(event.id),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.length ?? 0;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.groups_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text('$count', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
