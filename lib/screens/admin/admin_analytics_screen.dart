import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../models/event.dart';
import '../../models/event_index.dart';
import '../../services/event_service.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/state_views.dart';

/// Attendance and revenue at a glance.
class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: StreamBuilder<List<Event>>(
        stream: context.read<EventService>().watchEvents(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(
              message: 'Could not load analytics',
              detail: snapshot.error,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final events = snapshot.data!;
          final stats = context.watch<EventStatsIndex>();

          if (events.isEmpty) {
            return const EmptyState(
              icon: Icons.insights_outlined,
              title: 'Nothing to measure yet',
              message: 'Publish an event and its numbers will show up here.',
            );
          }

          // Revenue is booked seats x price. Ticketing has no payment step,
          // so this is what is owed rather than what has been collected -
          // the label says "expected" for exactly that reason.
          final revenue = events.fold<double>(
            0,
            (sum, e) => sum + e.charges * stats.seatsTakenOf(e.id),
          );

          final byBookings = events.toList()
            ..sort(
              (a, b) =>
                  stats.seatsTakenOf(b.id).compareTo(stats.seatsTakenOf(a.id)),
            );
          final topSix = byBookings
              .where((e) => stats.seatsTakenOf(e.id) > 0)
              .take(6)
              .toList();

          return ListView(
            padding: Gap.listInsets,
            children: [
              HeroMetric(
                value: Formatters.count(stats.totalSeatsTaken),
                label: 'Seats booked',
                caption:
                    '${Formatters.count(stats.totalCheckedIn)} checked in · '
                    '${Formatters.count(stats.totalWaitlisted)} waiting',
              ),
              Gap.h24,
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: Gap.md,
                crossAxisSpacing: Gap.md,
                childAspectRatio: 1.32,
                children: [
                  StatTile(
                    icon: Icons.event_outlined,
                    value: Formatters.count(events.length),
                    label: 'Events published',
                  ),
                  StatTile(
                    icon: Icons.how_to_reg_outlined,
                    value: Formatters.count(stats.totalCheckedIn),
                    label: 'Checked in at the gate',
                    accent: Theme.of(context).colorScheme.tertiary,
                  ),
                  StatTile(
                    icon: Icons.payments_outlined,
                    value: Formatters.money(revenue),
                    label: 'Expected revenue',
                  ),
                  StatTile(
                    icon: Icons.hourglass_top_outlined,
                    value: Formatters.count(stats.totalWaitlisted),
                    label: 'On waitlists',
                  ),
                ],
              ),
              Gap.h32,
              Text(
                'Most booked events',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Gap.h16,
              if (topSix.isEmpty)
                const EmptyState(
                  icon: Icons.bar_chart_rounded,
                  title: 'No bookings yet',
                  compact: true,
                )
              else
                HorizontalBarChart(
                  entries: [
                    for (final event in topSix)
                      BarChartEntry(
                        label: event.name,
                        value: stats.seatsTakenOf(event.id),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
