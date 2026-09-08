import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/event.dart';
import '../../models/event_filter.dart';
import '../../models/event_index.dart';
import '../../models/user_profile.dart';
import '../../services/event_service.dart';
import '../../services/favorite_service.dart';
import '../../theme/app_dimens.dart';
import '../../theme/category_style.dart';
import '../../widgets/event_card.dart';
import '../../widgets/featured_event_card.dart';
import '../../widgets/shimmer_box.dart';
import '../../widgets/state_views.dart';
import 'event_detail_screen.dart';
import 'event_filter_sheet.dart';

/// The browsing surface.
///
/// The old version was four tabs over one flat list - Upcoming, Ongoing,
/// Past, Favorites - which meant the most useful thing on screen was a time
/// filter and the least useful, finished events, got equal billing.
///
/// This is a single scroll with an editorial shape instead:
///
///  * a hero carousel of what is next, so opening the app shows something
///    rather than a wall of rows;
///  * "Happening now", which only appears when something actually is;
///  * then the full list, which is where search, filters and sorting apply.
///
/// The section rail collapses to just the list as soon as a filter or a query
/// is active - once someone is looking for something specific, curation is in
/// the way.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _searchController = TextEditingController();
  EventFilter _filter = EventFilter.none;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isBrowsing => _filter.isClear;

  @override
  Widget build(BuildContext context) {
    final eventService = context.read<EventService>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<Event>>(
          stream: eventService.watchEvents(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorView(
                message: 'Could not load events',
                detail: snapshot.error,
                onRetry: () => setState(() {}),
              );
            }
            if (!snapshot.hasData) {
              return const _DiscoverSkeleton();
            }
            return _DiscoverBody(
              profile: widget.profile,
              allEvents: snapshot.data!,
              filter: _filter,
              searchController: _searchController,
              isBrowsing: _isBrowsing,
              onQueryChanged: (query) =>
                  setState(() => _filter = _filter.copyWith(query: query)),
              onFilterChanged: (next) => setState(() => _filter = next),
            );
          },
        ),
      ),
    );
  }
}

class _DiscoverBody extends StatelessWidget {
  const _DiscoverBody({
    required this.profile,
    required this.allEvents,
    required this.filter,
    required this.searchController,
    required this.isBrowsing,
    required this.onQueryChanged,
    required this.onFilterChanged,
  });

  final UserProfile profile;
  final List<Event> allEvents;
  final EventFilter filter;
  final TextEditingController searchController;
  final bool isBrowsing;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<EventFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<EventStatsIndex>();
    final favorites = context.watch<FavoriteIndex>();
    final favoriteService = context.read<FavoriteService>();

    final now = DateTime.now();
    final seatsTaken = stats.seatsTaken;
    final matching = filter.apply(allEvents, seatsTaken: seatsTaken);

    final ongoing = allEvents
        .where((e) => e.statusAt(now) == EventStatus.ongoing)
        .toList();
    final featured = allEvents
        .where((e) => e.statusAt(now) == EventStatus.upcoming)
        .take(5)
        .toList();

    final tags = _collectTags(allEvents);

    void openEvent(Event event, {String heroPrefix = 'event-image'}) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(
            event: event,
            profile: profile,
            heroPrefix: heroPrefix,
          ),
        ),
      );
    }

    void toggleFavorite(Event event) {
      favoriteService.setFavorite(
        eventId: event.id,
        userId: profile.id,
        favorited: !favorites.contains(event.id),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _Greeting(
            name: profile.fullName,
            eventCount: allEvents.length,
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _ToolbarDelegate(
            controller: searchController,
            filter: filter,
            availableTags: tags,
            onQueryChanged: onQueryChanged,
            onFilterChanged: onFilterChanged,
          ),
        ),
        SliverToBoxAdapter(
          child: _CategoryRail(
            filter: filter,
            onFilterChanged: onFilterChanged,
          ),
        ),

        if (isBrowsing) ...[
          if (featured.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Coming up',
                subtitle: 'The next few on the calendar',
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 300 * 10 / 16,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: Gap.pageInsets,
                  clipBehavior: Clip.none,
                  itemCount: featured.length,
                  separatorBuilder: (_, _) => Gap.w12,
                  itemBuilder: (context, index) {
                    final event = featured[index];
                    return FeaturedEventCard(
                      event: event,
                      isFavorite: favorites.contains(event.id),
                      onToggleFavorite: () => toggleFavorite(event),
                      onTap: () => openEvent(event, heroPrefix: 'featured'),
                    );
                  },
                ),
              ),
            ),
          ],
          if (ongoing.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Happening now',
                subtitle: ongoing.length == 1
                    ? '1 event under way'
                    : '${ongoing.length} events under way',
              ),
            ),
            SliverPadding(
              padding: Gap.pageInsets,
              sliver: SliverList.separated(
                itemCount: ongoing.length,
                separatorBuilder: (_, _) => Gap.h12,
                itemBuilder: (context, index) {
                  final event = ongoing[index];
                  return EventCard(
                    event: event,
                    heroPrefix: 'ongoing',
                    seatsTaken: stats.seatsTakenOf(event.id),
                    isFavorite: favorites.contains(event.id),
                    onToggleFavorite: () => toggleFavorite(event),
                    onTap: () => openEvent(event, heroPrefix: 'ongoing'),
                  );
                },
              ),
            ),
          ],
        ],

        SliverToBoxAdapter(
          child: SectionHeader(
            title: isBrowsing ? 'All events' : 'Results',
            subtitle: _resultSummary(matching.length, filter),
            actionLabel: filter.isClear ? null : 'Clear',
            onAction: filter.isClear
                ? null
                : () {
                    searchController.clear();
                    onFilterChanged(EventFilter.none);
                  },
          ),
        ),

        if (matching.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: filter.isClear
                ? const EmptyState(
                    icon: Icons.event_busy_rounded,
                    title: 'No events yet',
                    message:
                        'Nothing has been published. Check back in a little while.',
                  )
                : EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Nothing matches',
                    message:
                        'Try a different search, or loosen the filters a little.',
                    actionLabel: 'Clear filters',
                    onAction: () {
                      searchController.clear();
                      onFilterChanged(EventFilter.none);
                    },
                  ),
          )
        else
          SliverPadding(
            padding: Gap.listInsets,
            sliver: SliverList.separated(
              itemCount: matching.length,
              separatorBuilder: (_, _) => Gap.h12,
              itemBuilder: (context, index) {
                final event = matching[index];
                return EventCard(
                  event: event,
                  seatsTaken: stats.seatsTakenOf(event.id),
                  isFavorite: favorites.contains(event.id),
                  onToggleFavorite: () => toggleFavorite(event),
                  onTap: () => openEvent(event),
                );
              },
            ),
          ),
      ],
    );
  }

  static String _resultSummary(int count, EventFilter filter) {
    final noun = count == 1 ? 'event' : 'events';
    if (filter.isClear) return '$count $noun';
    if (filter.query.trim().isEmpty) return '$count $noun match your filters';
    return '$count $noun for "${filter.query.trim()}"';
  }

  /// Tags in descending popularity, so the filter sheet leads with the ones
  /// actually in use rather than in alphabetical order.
  static List<String> _collectTags(List<Event> events) {
    final counts = <String, int>{};
    for (final event in events) {
      for (final tag in event.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final tags = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    return tags;
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.eventCount});

  final String name;
  final int eventCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final firstName = name.trim().split(RegExp(r'\s+')).first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting, $firstName',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          Gap.h4,
          Text('Discover', style: text.headlineMedium),
        ],
      ),
    );
  }
}

/// Search field plus the filter button, pinned so both stay reachable however
/// far the list has been scrolled.
class _ToolbarDelegate extends SliverPersistentHeaderDelegate {
  _ToolbarDelegate({
    required this.controller,
    required this.filter,
    required this.availableTags,
    required this.onQueryChanged,
    required this.onFilterChanged,
  });

  final TextEditingController controller;
  final EventFilter filter;
  final List<String> availableTags;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<EventFilter> onFilterChanged;

  static const double _height = 72;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final activeCount = filter.activeCriteriaCount;

    return Container(
      height: _height,
      // Opaque, so list rows do not show through the pinned toolbar.
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.md),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search events, venues, tags',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Gap.lg,
                  vertical: Gap.md,
                ),
                suffixIcon: filter.query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          controller.clear();
                          onQueryChanged('');
                        },
                      ),
              ),
            ),
          ),
          Gap.w8,
          _FilterButton(
            activeCount: activeCount,
            onTap: () async {
              final next = await showEventFilterSheet(
                context,
                current: filter,
                availableTags: availableTags,
              );
              if (next != null) onFilterChanged(next);
            },
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_ToolbarDelegate oldDelegate) {
    return oldDelegate.filter != filter ||
        oldDelegate.availableTags.length != availableTags.length;
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.activeCount, required this.onTap});

  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = activeCount > 0;

    return Tooltip(
      message: 'Filter and sort',
      child: InkWell(
        onTap: onTap,
        borderRadius: Corner.mdAll,
        child: Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: active ? scheme.primary : scheme.surface,
            borderRadius: Corner.mdAll,
            border: Border.all(
              color: active ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Center(
            child: active
                ? Text(
                    '$activeCount',
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: scheme.onPrimary),
                  )
                : Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
          ),
        ),
      ),
    );
  }
}

/// The one filter worth keeping permanently on screen.
class _CategoryRail extends StatelessWidget {
  const _CategoryRail({required this.filter, required this.onFilterChanged});

  final EventFilter filter;
  final ValueChanged<EventFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: Gap.pageInsets,
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: filter.categories.isEmpty,
            onSelected: (_) =>
                onFilterChanged(filter.copyWith(categories: const {})),
          ),
          for (final category in EventCategory.values) ...[
            Gap.w8,
            ChoiceChip(
              avatar: Icon(
                CategoryStyle.iconOf(category),
                size: 15,
                color: CategoryStyle.tintOf(
                  category,
                  Theme.of(context).brightness,
                ),
              ),
              label: Text(category.label),
              selected: filter.categories.contains(category),
              // Tapping a rail chip selects just that one. Multi-select
              // lives in the sheet; here it should behave like a segmented
              // control.
              onSelected: (selected) => onFilterChanged(
                filter.copyWith(categories: selected ? {category} : const {}),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscoverSkeleton extends StatelessWidget {
  const _DiscoverSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: Gap.xl),
      children: const [
        Padding(
          padding: Gap.pageInsets,
          child: ShimmerBox(height: 26, width: 160),
        ),
        Gap.h24,
        FeaturedShimmer(),
        Gap.h24,
        Padding(
          padding: Gap.pageInsets,
          child: ShimmerBox(height: 20, width: 120),
        ),
        Gap.h12,
        SizedBox(height: 420, child: EventListShimmer(itemCount: 3)),
      ],
    );
  }
}
