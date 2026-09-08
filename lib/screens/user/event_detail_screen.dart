import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/launchers.dart';
import '../../models/agenda_item.dart';
import '../../models/event.dart';
import '../../models/event_image.dart';
import '../../models/event_index.dart';
import '../../models/ticket.dart';
import '../../models/user_profile.dart';
import '../../services/event_service.dart';
import '../../services/favorite_service.dart';
import '../../services/ticket_service.dart';
import '../../theme/app_dimens.dart';
import '../../theme/category_style.dart';
import '../../widgets/capacity_meter.dart';
import '../../widgets/event_cover.dart';
import '../../widgets/favorite_heart_button.dart';
import '../../widgets/status_badge.dart';
import 'ticket_pass_screen.dart';

/// Everything about one event, and the place a ticket is booked.
///
/// The booking control sits in a persistent bottom bar rather than inline in
/// the scroll: it is the reason the screen exists, and inline it disappears
/// the moment someone reads the description. The bar also carries the price
/// and the seats-left line, so the decision and the information behind it are
/// never on different screens.
class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({
    super.key,
    required this.event,
    required this.profile,
    this.heroPrefix = 'event-image',
  });

  final Event event;
  final UserProfile profile;
  final String heroPrefix;

  @override
  Widget build(BuildContext context) {
    final eventService = context.read<EventService>();
    final stats = context.watch<EventStatsIndex>().of(event.id);
    final favorites = context.watch<FavoriteIndex>();
    final isFavorite = favorites.contains(event.id);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _CoverAppBar(
            event: event,
            heroPrefix: heroPrefix,
            isFavorite: isFavorite,
            onToggleFavorite: () => context.read<FavoriteService>().setFavorite(
              eventId: event.id,
              userId: profile.id,
              favorited: !isFavorite,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Gap.page,
              Gap.xl,
              Gap.page,
              Gap.xxxl,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _Headline(event: event),
                Gap.h20,
                _WhenWhereCard(event: event),

                if (event.isLimited) ...[
                  Gap.h16,
                  _Panel(
                    title: 'Availability',
                    child: CapacityMeter(
                      seatsTaken: stats.seatsTaken,
                      capacity: event.capacity!,
                      waitlisted: stats.waitlisted,
                    ),
                  ),
                ],

                _AgendaSection(eventId: event.id, service: eventService),
                _GallerySection(eventId: event.id, service: eventService),

                Gap.h24,
                Text(
                  'About this event',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Gap.h8,
                Text(
                  event.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),

                if (event.tags.isNotEmpty) ...[
                  Gap.h20,
                  Wrap(
                    spacing: Gap.sm,
                    runSpacing: Gap.sm,
                    children: [
                      for (final tag in event.tags)
                        Chip(
                          label: Text(tag),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],

                _OrganizerSection(event: event),

                Gap.h24,
                OutlinedButton.icon(
                  onPressed: () => _addToCalendar(context),
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: const Text('Add to calendar'),
                ),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BookingBar(event: event, profile: profile),
    );
  }

  Future<void> _addToCalendar(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    // The running order goes into the .ics description, so a saved event
    // carries the schedule with it rather than sending the user back here.
    final agenda = await context.read<EventService>().fetchAgenda(event.id);
    final ok = await Launchers.addToCalendar(event, agenda: agenda);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not build the calendar file.')),
      );
    }
  }
}

class _CoverAppBar extends StatelessWidget {
  const _CoverAppBar({
    required this.event,
    required this.heroPrefix,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final Event event;
  final String heroPrefix;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      // White chrome over the photo regardless of theme, since the image
      // behind it is unknown; the scrim is what guarantees the contrast.
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      actions: [
        IconButton(
          tooltip: 'Share',
          icon: const Icon(Icons.ios_share_rounded),
          onPressed: () => Launchers.shareEvent(event),
        ),
        Padding(
          padding: const EdgeInsets.only(right: Gap.xs),
          child: FavoriteHeartButton(
            isFavorite: isFavorite,
            onToggle: onToggleFavorite,
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: '$heroPrefix-${event.id}',
              child: EventCover(event: event, fallbackIconSize: 72),
            ),
            const CoverScrim(strength: 0.62),
            Positioned(
              left: Gap.page,
              bottom: Gap.lg,
              child: StatusBadge(status: event.statusAt(DateTime.now())),
            ),
          ],
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tint = CategoryStyle.tintOf(
      event.category,
      Theme.of(context).brightness,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(CategoryStyle.iconOf(event.category), size: 15, color: tint),
            Gap.w6,
            Text(
              event.category.label.toUpperCase(),
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Gap.w8,
            Text(
              '• ${Formatters.relativeToNow(event.eventDate)}',
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        Gap.h8,
        Text(event.name, style: text.headlineMedium),
      ],
    );
  }
}

/// The three facts every attendee checks first, in one block.
class _WhenWhereCard extends StatelessWidget {
  const _WhenWhereCard({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          children: [
            _Fact(
              icon: Icons.event_rounded,
              label: 'Starts',
              value: Formatters.fullDateTime.format(event.eventDate),
            ),
            const Divider(height: Gap.xl),
            _Fact(
              icon: Icons.timelapse_rounded,
              label: 'Runs for',
              value:
                  '${Formatters.span(event.eventDate, event.endDate)}'
                  ' · ends ${Formatters.timeOnly.format(event.endDate)}',
            ),
            if (event.venueLine != null) ...[
              const Divider(height: Gap.xl),
              _Fact(
                icon: Icons.place_rounded,
                label: 'Venue',
                value: event.venueLine!,
                actionLabel: 'Directions',
                onAction: () => _openMap(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openMap(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await Launchers.openMap(
      latitude: event.latitude,
      longitude: event.longitude,
      query: event.venueLine,
    );
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No maps app could open this location.')),
      );
    }
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        Gap.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: text.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Gap.h2,
              Text(value, style: text.bodyMedium),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Gap.h12,
            child,
          ],
        ),
      ),
    );
  }
}

/// Running order. Renders nothing at all when the event has no agenda, rather
/// than an empty "Schedule" heading - most events will not have one.
class _AgendaSection extends StatelessWidget {
  const _AgendaSection({required this.eventId, required this.service});

  final String eventId;
  final EventService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AgendaItem>>(
      stream: service.watchAgenda(eventId),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <AgendaItem>[];
        if (items.isEmpty) return const SizedBox.shrink();

        final now = DateTime.now();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Gap.h24,
            Text(
              'Running order',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Gap.h12,
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.xs),
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: Gap.lg),
                      _AgendaRow(
                        item: items[i],
                        isCurrent: items[i].isCurrentAt(now),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({required this.item, required this.isCurrent});

  final AgendaItem item;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      color: isCurrent ? scheme.primary.withValues(alpha: 0.06) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Text(
              Formatters.timeOnly.format(item.startsAt),
              style: text.labelMedium?.copyWith(
                color: isCurrent ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: text.bodyMedium),
                if (item.hasSpeaker) ...[
                  Gap.h2,
                  Text(
                    item.speaker!,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isCurrent)
            Padding(
              padding: const EdgeInsets.only(left: Gap.sm),
              child: Icon(
                Icons.sensors_rounded,
                size: 15,
                color: scheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _GallerySection extends StatelessWidget {
  const _GallerySection({required this.eventId, required this.service});

  final String eventId;
  final EventService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EventImage>>(
      stream: service.watchImages(eventId),
      builder: (context, snapshot) {
        final images = snapshot.data ?? const <EventImage>[];
        if (images.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Gap.h24,
            Text('Gallery', style: Theme.of(context).textTheme.titleMedium),
            Gap.h12,
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: images.length,
                separatorBuilder: (_, _) => Gap.w8,
                itemBuilder: (context, index) =>
                    _GalleryTile(images: images, index: index),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({required this.images, required this.index});

  final List<EventImage> images;
  final int index;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: Corner.mdAll,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _GalleryViewer(images: images, initialIndex: index),
        ),
      ),
      child: ClipRRect(
        borderRadius: Corner.mdAll,
        child: Image.network(
          images[index].imageUrl,
          width: 160,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (context, _, _) => Container(
            width: 160,
            height: 120,
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Icon(
              Icons.broken_image_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen, swipeable gallery. Black regardless of theme - a photo viewer
/// on a white ground fights the photo.
class _GalleryViewer extends StatelessWidget {
  const _GalleryViewer({required this.images, required this.initialIndex});

  final List<EventImage> images;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${initialIndex + 1} of ${images.length}'),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: images.length,
        itemBuilder: (context, index) => InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: Image.network(images[index].imageUrl, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _OrganizerSection extends StatelessWidget {
  const _OrganizerSection({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    if (event.organizerName == null && !event.hasOrganizerContact) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Gap.h24,
        Text('Organiser', style: text.titleMedium),
        Gap.h12,
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.organizerName ?? 'Event desk',
                        style: text.bodyLarge,
                      ),
                      if (event.organizerEmail != null) ...[
                        Gap.h2,
                        Text(
                          event.organizerEmail!,
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (event.organizerPhone != null)
                  IconButton(
                    tooltip: 'Call',
                    icon: const Icon(Icons.call_rounded),
                    onPressed: () => Launchers.dial(event.organizerPhone!),
                  ),
                if (event.organizerEmail != null)
                  IconButton(
                    tooltip: 'Email',
                    icon: const Icon(Icons.mail_outline_rounded),
                    onPressed: () => Launchers.email(
                      event.organizerEmail!,
                      subject: event.name,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The persistent booking bar.
///
/// Its state comes from the caller's own ticket row, which is why cancelled
/// is distinguishable from never-booked: the copy for someone who backed out
/// and is reconsidering should not be the same as for a first-time visitor.
class _BookingBar extends StatefulWidget {
  const _BookingBar({required this.event, required this.profile});

  final Event event;
  final UserProfile profile;

  @override
  State<_BookingBar> createState() => _BookingBarState();
}

class _BookingBarState extends State<_BookingBar> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ticketService = context.read<TicketService>();
    final stats = context.watch<EventStatsIndex>().of(widget.event.id);
    final event = widget.event;

    return StreamBuilder<Ticket?>(
      stream: ticketService.watchMyTicketFor(
        eventId: event.id,
        userId: widget.profile.id,
      ),
      builder: (context, snapshot) {
        final ticket = snapshot.data;
        final holdsTicket = ticket != null && ticket.isActive;
        final soldOut = event.isLimited && event.isSoldOut(stats.seatsTaken);
        final finished = !event.isBookable;

        final (String label, IconData icon, VoidCallback? action) = switch ((
          finished,
          holdsTicket,
          soldOut,
        )) {
          (true, true, _) => (
            'View pass',
            Icons.qr_code_2_rounded,
            () => _openPass(ticket!),
          ),
          (true, false, _) => (
            'Event finished',
            Icons.event_busy_rounded,
            null,
          ),
          (false, true, _) => (
            'View pass',
            Icons.qr_code_2_rounded,
            () => _openPass(ticket!),
          ),
          (false, false, true) => (
            'Join waitlist',
            Icons.hourglass_top_rounded,
            _book,
          ),
          (false, false, false) => (
            'Get ticket',
            Icons.confirmation_number_rounded,
            _book,
          ),
        };

        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(
              Gap.page,
              Gap.md,
              Gap.page,
              Gap.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        Formatters.price(event.charges),
                        style: text.titleLarge?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      Gap.h2,
                      Text(
                        _subline(event, ticket, stats),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Gap.w12,
                if (holdsTicket && !finished)
                  IconButton(
                    tooltip: 'Cancel booking',
                    onPressed: _busy ? null : () => _confirmCancel(ticket),
                    icon: const Icon(Icons.close_rounded),
                  ),
                FilledButton.icon(
                  onPressed: _busy ? null : action,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(icon, size: 18),
                  label: Text(label),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(146, 50),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _subline(Event event, Ticket? ticket, EventStats stats) {
    if (ticket != null && ticket.isActive) {
      return ticket.status == TicketStatus.waitlisted
          ? 'You are on the waitlist'
          : 'Ticket ${ticket.code}';
    }
    if (ticket?.status == TicketStatus.cancelled) {
      return 'You cancelled this booking';
    }
    if (!event.isBookable) return 'Booking closed';
    if (!event.isLimited) return 'Open entry';
    final left = event.seatsLeft(stats.seatsTaken) ?? 0;
    return left <= 0
        ? 'Sold out · ${Formatters.count(stats.waitlisted)} waiting'
        : '${Formatters.count(left)} seats left';
  }

  void _openPass(Ticket ticket) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TicketPassScreen(ticket: ticket, event: widget.event),
      ),
    );
  }

  Future<void> _book() async {
    final messenger = ScaffoldMessenger.of(context);
    final service = context.read<TicketService>();
    setState(() => _busy = true);
    try {
      final ticket = await service.book(widget.event.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ticket.status == TicketStatus.waitlisted
                ? 'The event is full - you are on the waitlist.'
                : 'Booked. Your pass is ${ticket.code}.',
          ),
        ),
      );
    } on TicketException catch (e) {
      // The database raises human-readable messages, so they are shown as
      // written rather than replaced with a generic failure.
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not book right now.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmCancel(Ticket ticket) async {
    final waitlisted = ticket.status == TicketStatus.waitlisted;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(waitlisted ? 'Leave the waitlist?' : 'Cancel your ticket?'),
        content: Text(
          waitlisted
              ? 'You will lose your place in the queue.'
              : 'Your seat goes back into the pool and the next person on the '
                    'waitlist takes it. You can book again if space remains.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(waitlisted ? 'Leave' : 'Cancel ticket'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final service = context.read<TicketService>();
    setState(() => _busy = true);
    try {
      await service.cancel(widget.event.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Booking cancelled.')),
      );
    } on TicketException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
