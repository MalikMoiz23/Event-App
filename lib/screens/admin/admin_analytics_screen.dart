import 'package:flutter/material.dart';
import '../../models/event.dart';
import '../../services/event_service.dart';
import '../../services/rsvp_service.dart';
import '../../widgets/simple_bar_chart.dart';
import '../../widgets/stat_tile.dart';

class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({
    super.key,
    required this.eventService,
    required this.rsvpService,
  });

  final EventService eventService;
  final RsvpService rsvpService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: StreamBuilder<List<Event>>(
        stream: eventService.watchEvents(),
        builder: (context, eventSnapshot) {
          if (!eventSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = eventSnapshot.data!;

          return StreamBuilder<List<String>>(
            stream: rsvpService.watchAllEventIds(),
            builder: (context, rsvpSnapshot) {
              final rsvpEventIds = rsvpSnapshot.data ?? const <String>[];

              final countByEvent = <String, int>{};
              for (final id in rsvpEventIds) {
                countByEvent[id] = (countByEvent[id] ?? 0) + 1;
              }

              final chargesById = {for (final e in events) e.id: e.charges};
              final revenue = rsvpEventIds.fold<double>(
                0,
                (sum, eventId) => sum + (chargesById[eventId] ?? 0),
              );

              final topEvents = events.toList()
                ..sort(
                  (a, b) => (countByEvent[b.id] ?? 0).compareTo(
                    countByEvent[a.id] ?? 0,
                  ),
                );
              final chartEntries = topEvents
                  .take(6)
                  .map(
                    (e) => BarChartEntry(
                      label: e.name,
                      value: countByEvent[e.id] ?? 0,
                    ),
                  )
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      StatTile(
                        icon: Icons.event_outlined,
                        value: '${events.length}',
                        label: 'Total events',
                      ),
                      StatTile(
                        icon: Icons.groups_outlined,
                        value: '${rsvpEventIds.length}',
                        label: 'Total RSVPs',
                      ),
                      StatTile(
                        icon: Icons.payments_outlined,
                        value: 'PKR ${revenue.toStringAsFixed(0)}',
                        label: 'Est. revenue',
                      ),
                      StatTile(
                        icon: Icons.local_fire_department_outlined,
                        value: topEvents.isEmpty
                            ? '-'
                            : topEvents.first.name,
                        label: 'Most popular',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'RSVPs by event',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (chartEntries.isEmpty || rsvpEventIds.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('No RSVPs yet.')),
                    )
                  else
                    SimpleBarChart(entries: chartEntries),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
