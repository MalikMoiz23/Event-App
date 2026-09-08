import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../models/event.dart';
import '../../models/ticket.dart';
import '../../models/user_profile.dart';
import '../../services/event_service.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/event_cover.dart';
import '../../widgets/shimmer_box.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_badge.dart';
import 'event_detail_screen.dart';
import 'ticket_pass_screen.dart';

/// The attendee's bookings.
///
/// Grouped by what the user can still do with them rather than by status:
/// "Coming up" is the only group that matters at a gate, so it leads and is
/// the only one expanded by default. Cancelled bookings are kept rather than
/// hidden, because "did I actually cancel that?" is a real question and a
/// missing row does not answer it.
class MyTicketsScreen extends StatelessWidget {
  const MyTicketsScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final tickets = context.watch<List<Ticket>>();

    return Scaffold(
      appBar: AppBar(title: const Text('My tickets')),
      body: StreamBuilder<List<Event>>(
        stream: context.read<EventService>().watchEvents(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(
              message: 'Could not load your tickets',
              detail: snapshot.error,
            );
          }
          if (!snapshot.hasData) return const EventListShimmer(itemCount: 3);

          final eventsById = {for (final e in snapshot.data!) e.id: e};
          final now = DateTime.now();

          // A ticket whose event has been deleted has nothing to show, so it
          // is dropped rather than rendered as a row with blank fields.
          final pairs = tickets
              .where((t) => eventsById.containsKey(t.eventId))
              .map((t) => (ticket: t, event: eventsById[t.eventId]!))
              .toList();

          final upcoming =
              pairs
                  .where(
                    (p) => p.ticket.isActive && p.event.endDate.isAfter(now),
                  )
                  .toList()
                ..sort(
                  (a, b) => a.event.eventDate.compareTo(b.event.eventDate),
                );

          final past =
              pairs
                  .where(
                    (p) => p.ticket.isActive && !p.event.endDate.isAfter(now),
                  )
                  .toList()
                ..sort(
                  (a, b) => b.event.eventDate.compareTo(a.event.eventDate),
                );

          final cancelled =
              pairs
                  .where((p) => p.ticket.status == TicketStatus.cancelled)
                  .toList()
                ..sort(
                  (a, b) => b.ticket.bookedAt.compareTo(a.ticket.bookedAt),
                );

          if (pairs.isEmpty) {
            return const EmptyState(
              icon: Icons.confirmation_number_outlined,
              title: 'No tickets yet',
              message:
                  'Book an event from Discover and your pass will appear here.',
            );
          }

          return ListView(
            padding: Gap.listInsets,
            children: [
              if (upcoming.isNotEmpty) ...[
                _GroupHeader(
                  title: 'Coming up',
                  count: upcoming.length,
                  padding: const EdgeInsets.only(bottom: Gap.md),
                ),
                for (final pair in upcoming) ...[
                  _TicketRow(
                    ticket: pair.ticket,
                    event: pair.event,
                    profile: profile,
                    highlight: true,
                  ),
                  Gap.h12,
                ],
              ],
              if (past.isNotEmpty) ...[
                _GroupHeader(title: 'Attended', count: past.length),
                for (final pair in past) ...[
                  _TicketRow(
                    ticket: pair.ticket,
                    event: pair.event,
                    profile: profile,
                  ),
                  Gap.h12,
                ],
              ],
              if (cancelled.isNotEmpty) ...[
                _GroupHeader(title: 'Cancelled', count: cancelled.length),
                for (final pair in cancelled) ...[
                  _TicketRow(
                    ticket: pair.ticket,
                    event: pair.event,
                    profile: profile,
                  ),
                  Gap.h12,
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.count,
    this.padding = const EdgeInsets.only(top: Gap.xl, bottom: Gap.md),
  });

  final String title;
  final int count;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          Gap.w8,
          Text(
            '$count',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({
    required this.ticket,
    required this.event,
    required this.profile,
    this.highlight = false,
  });

  final Ticket ticket;
  final Event event;
  final UserProfile profile;

  /// Coming-up tickets get the pass button; the rest are records.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final canScan = ticket.status == TicketStatus.confirmed;

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(
              event: event,
              profile: profile,
              heroPrefix: 'ticket',
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: Corner.mdAll,
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: Hero(
                    tag: 'ticket-${event.id}',
                    child: EventCover(event: event, fallbackIconSize: 22),
                  ),
                ),
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(fontSize: 15),
                    ),
                    Gap.h4,
                    Text(
                      Formatters.mediumDateTime.format(event.eventDate),
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Gap.h8,
                    Row(
                      children: [
                        TicketStatusBadge(status: ticket.status, dense: true),
                        Gap.w8,
                        Expanded(
                          child: Text(
                            ticket.code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (highlight && canScan)
                IconButton.filledTonal(
                  tooltip: 'Show pass',
                  icon: const Icon(Icons.qr_code_2_rounded),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          TicketPassScreen(ticket: ticket, event: event),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
