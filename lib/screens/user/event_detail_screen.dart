import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/event.dart';
import '../../services/favorite_service.dart';
import '../../services/rsvp_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/favorite_heart_button.dart';
import '../../widgets/status_badge.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.event,
    required this.userId,
    required this.rsvpService,
    required this.favoriteService,
    required this.isFavorite,
  });

  final Event event;
  final String userId;
  final RsvpService rsvpService;
  final FavoriteService favoriteService;
  final bool isFavorite;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late bool _isFavorite = widget.isFavorite;

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
    widget.favoriteService.setFavorite(
      eventId: widget.event.id,
      userId: widget.userId,
      favorited: _isFavorite,
    );
  }

  void _shareEvent() {
    final e = widget.event;
    final dateFormat = DateFormat('EEEE, d MMMM yyyy • h:mm a');
    SharePlus.instance.share(
      ShareParams(
        subject: e.name,
        text:
            '${e.name}\n${dateFormat.format(e.eventDate)}\n'
            '${e.isFree ? 'Free entry' : 'PKR ${e.charges.toStringAsFixed(0)}'}\n\n'
            '${e.description}\n\nvia HIT EVO',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final dateFormat = DateFormat('EEEE, d MMMM yyyy • h:mm a');
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: _shareEvent,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FavoriteHeartButton(
                  isFavorite: _isFavorite,
                  onToggle: _toggleFavorite,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'event-image-${event.id}',
                child: event.imageUrl == null
                    ? Container(
                        color: AppColors.hitRed,
                        child: const Icon(
                          Icons.event,
                          size: 72,
                          color: Colors.white70,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: event.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            Container(color: AppColors.hitRed),
                      ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.name,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(status: event.statusAt(DateTime.now())),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(event.category.label)),
                      Chip(
                        label: Text(
                          event.isFree
                              ? 'Free entry'
                              : 'PKR ${event.charges.toStringAsFixed(0)}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Starts',
                    value: dateFormat.format(event.eventDate),
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.event_available_outlined,
                    label: 'Ends',
                    value: dateFormat.format(event.endDate),
                  ),
                  const SizedBox(height: 24),
                  _RsvpSection(
                    event: event,
                    userId: widget.userId,
                    rsvpService: widget.rsvpService,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'About this event',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RsvpSection extends StatelessWidget {
  const _RsvpSection({
    required this.event,
    required this.userId,
    required this.rsvpService,
  });

  final Event event;
  final String userId;
  final RsvpService rsvpService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: rsvpService.watchAttendees(event.id),
      builder: (context, snapshot) {
        final attendees = snapshot.data ?? const <String>[];
        final going = attendees.contains(userId);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.hitRed.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${attendees.length}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.hitRedDark,
                      ),
                    ),
                    Text(
                      attendees.length == 1 ? 'person going' : 'people going',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => rsvpService.setGoing(
                  eventId: event.id,
                  userId: userId,
                  going: !going,
                ),
                icon: Icon(going ? Icons.check_circle : Icons.add_circle_outline),
                label: Text(going ? "I'm Going" : "I'm Going?"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: going ? AppColors.statusOngoing : AppColors.hitRed,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.hitRed),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
