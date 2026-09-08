import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/csv_export.dart';
import '../../core/formatters.dart';
import '../../core/launchers.dart';
import '../../models/event.dart';
import '../../models/ticket.dart';
import '../../services/ticket_service.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/settings_widgets.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_badge.dart';

/// Who is coming to one event, and who has actually arrived.
///
/// Fetched once with pull-to-refresh rather than streamed. A roster is read
/// deliberately - before doors, or to settle a dispute at the gate - and a
/// list that reorders itself under your thumb while you are looking for a
/// name is worse than one you refresh yourself.
///
/// The export is a real CSV: fields are quoted only when they need to be, and
/// a value starting with `=` is prefixed so a spreadsheet treats it as text
/// rather than a formula.
class AttendeeRosterScreen extends StatefulWidget {
  const AttendeeRosterScreen({super.key, required this.event});

  final Event event;

  @override
  State<AttendeeRosterScreen> createState() => _AttendeeRosterScreenState();
}

class _AttendeeRosterScreenState extends State<AttendeeRosterScreen> {
  late Future<List<Ticket>> _roster;
  String _query = '';
  _RosterFilter _filter = _RosterFilter.all;

  @override
  void initState() {
    super.initState();
    _roster = _load();
  }

  Future<List<Ticket>> _load() =>
      context.read<TicketService>().fetchRoster(widget.event.id);

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _roster = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendees'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(left: Gap.page, bottom: Gap.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.event.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Ticket>>(
        future: _roster,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(
              message: 'Could not load the attendee list',
              detail: snapshot.error,
              onRetry: _refresh,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data!;
          if (all.isEmpty) {
            return const EmptyState(
              icon: Icons.groups_outlined,
              title: 'Nobody has booked yet',
              message: 'Attendees appear here as soon as tickets go out.',
            );
          }

          final visible = all.where((t) {
            if (!_filter.matches(t)) return false;
            if (_query.trim().isEmpty) return true;
            final needle = _query.trim().toLowerCase();
            return (t.attendeeName ?? '').toLowerCase().contains(needle) ||
                (t.attendeeEmail ?? '').toLowerCase().contains(needle) ||
                t.code.toLowerCase().contains(needle);
          }).toList();

          final confirmed = all.where((t) => t.isActive).length;
          final arrived = all.where((t) => t.isCheckedIn).length;
          final waiting = all
              .where((t) => t.status == TicketStatus.waitlisted)
              .length;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: Gap.listInsets,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MiniStat(
                        icon: Icons.confirmation_number_outlined,
                        value: '$confirmed',
                        label: 'Booked',
                      ),
                    ),
                    Gap.w12,
                    Expanded(
                      child: MiniStat(
                        icon: Icons.how_to_reg_outlined,
                        value: '$arrived',
                        label: 'Arrived',
                      ),
                    ),
                    Gap.w12,
                    Expanded(
                      child: MiniStat(
                        icon: Icons.hourglass_top_outlined,
                        value: '$waiting',
                        label: 'Waitlist',
                      ),
                    ),
                  ],
                ),
                Gap.h16,
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Search name, email or code',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                  ),
                ),
                Gap.h12,
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final option in _RosterFilter.values) ...[
                        ChoiceChip(
                          label: Text(option.label),
                          selected: _filter == option,
                          onSelected: (_) => setState(() => _filter = option),
                        ),
                        Gap.w8,
                      ],
                    ],
                  ),
                ),
                Gap.h16,
                if (visible.isEmpty)
                  const EmptyState(
                    icon: Icons.person_search_outlined,
                    title: 'No matches',
                    compact: true,
                  )
                else
                  for (final ticket in visible) ...[
                    _RosterRow(ticket: ticket),
                    const Divider(height: 1),
                  ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: FutureBuilder<List<Ticket>>(
        future: _roster,
        builder: (context, snapshot) {
          final tickets = snapshot.data;
          return FloatingActionButton.extended(
            onPressed: tickets == null || tickets.isEmpty
                ? null
                : () => _export(tickets),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Export CSV'),
          );
        },
      ),
    );
  }

  Future<void> _export(List<Ticket> tickets) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await Launchers.shareText(
      fileName: CsvExport.fileName(widget.event),
      contents: CsvExport.roster(tickets),
      mimeType: 'text/csv',
      subject: '${widget.event.name} - attendees',
      text:
          '${tickets.length} attendee'
          '${tickets.length == 1 ? '' : 's'} for ${widget.event.name}',
    );
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not build the CSV file.')),
      );
    }
  }
}

enum _RosterFilter {
  all('Everyone'),
  arrived('Arrived'),
  expected('Not arrived'),
  waitlist('Waitlist'),
  cancelled('Cancelled');

  const _RosterFilter(this.label);

  final String label;

  bool matches(Ticket ticket) => switch (this) {
    _RosterFilter.all => true,
    _RosterFilter.arrived => ticket.isCheckedIn,
    _RosterFilter.expected => ticket.status == TicketStatus.confirmed,
    _RosterFilter.waitlist => ticket.status == TicketStatus.waitlisted,
    _RosterFilter.cancelled => ticket.status == TicketStatus.cancelled,
  };
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final name = ticket.attendeeName ?? 'Unknown attendee';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.md),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                IdentityCard.initialsOf(name),
                style: text.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyLarge,
                ),
                Gap.h2,
                Text(
                  ticket.attendeeEmail ?? ticket.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Gap.w8,
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TicketStatusBadge(status: ticket.status, dense: true),
              if (ticket.checkedInAt != null) ...[
                Gap.h4,
                Text(
                  Formatters.timeOnly.format(ticket.checkedInAt!),
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
