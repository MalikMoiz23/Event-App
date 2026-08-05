import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/event.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/favorite_service.dart';
import '../../services/rsvp_service.dart';
import '../../services/theme_controller.dart';
import '../../theme/hit_logo.dart';
import '../../widgets/event_card.dart';
import '../../widgets/shimmer_box.dart';
import '../../widgets/staggered_fade_slide.dart';
import 'event_detail_screen.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({
    super.key,
    required this.profile,
    required this.eventService,
    required this.authService,
    required this.rsvpService,
    required this.favoriteService,
  });

  final UserProfile profile;
  final EventService eventService;
  final AuthService authService;
  final RsvpService rsvpService;
  final FavoriteService favoriteService;

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  EventCategory? _categoryFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Event> _applyFilters(List<Event> events) {
    return events.where((e) {
      final matchesQuery =
          _query.isEmpty || e.name.toLowerCase().contains(_query.toLowerCase());
      final matchesCategory =
          _categoryFilter == null || e.category == _categoryFilter;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HitLogo(size: 32),
              const SizedBox(width: 10),
              const Text('HIT EVO'),
            ],
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Ongoing'),
              Tab(text: 'Past'),
              Tab(text: 'Favorites'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Toggle theme',
              icon: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
              onPressed: () => context.read<ThemeController>().toggle(),
            ),
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () => widget.authService.signOut(),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search events',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _CategoryChip(
                    label: 'All',
                    selected: _categoryFilter == null,
                    onSelected: () => setState(() => _categoryFilter = null),
                  ),
                  for (final category in EventCategory.values)
                    _CategoryChip(
                      label: category.label,
                      selected: _categoryFilter == category,
                      onSelected: () =>
                          setState(() => _categoryFilter = category),
                    ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Event>>(
                stream: widget.eventService.watchEvents(),
                builder: (context, eventSnapshot) {
                  if (eventSnapshot.connectionState == ConnectionState.waiting) {
                    return const EventListShimmer();
                  }
                  if (eventSnapshot.hasError) {
                    return Center(
                      child: Text('Failed to load events: ${eventSnapshot.error}'),
                    );
                  }
                  final events = _applyFilters(eventSnapshot.data ?? []);
                  final now = DateTime.now();
                  final upcoming = events
                      .where((e) => e.statusAt(now) == EventStatus.upcoming)
                      .toList();
                  final ongoing = events
                      .where((e) => e.statusAt(now) == EventStatus.ongoing)
                      .toList();
                  final past = events
                      .where((e) => e.statusAt(now) == EventStatus.past)
                      .toList()
                      .reversed
                      .toList();

                  return StreamBuilder<Set<String>>(
                    stream: widget.favoriteService.watchFavoriteEventIds(
                      widget.profile.id,
                    ),
                    builder: (context, favSnapshot) {
                      final favoriteIds = favSnapshot.data ?? const <String>{};
                      final favorites = events
                          .where((e) => favoriteIds.contains(e.id))
                          .toList();
                      return TabBarView(
                        children: [
                          _EventList(
                            events: upcoming,
                            emptyText: 'No upcoming events yet.',
                            favoriteIds: favoriteIds,
                            userId: widget.profile.id,
                            rsvpService: widget.rsvpService,
                            favoriteService: widget.favoriteService,
                          ),
                          _EventList(
                            events: ongoing,
                            emptyText: 'No events happening right now.',
                            favoriteIds: favoriteIds,
                            userId: widget.profile.id,
                            rsvpService: widget.rsvpService,
                            favoriteService: widget.favoriteService,
                          ),
                          _EventList(
                            events: past,
                            emptyText: 'No past events.',
                            favoriteIds: favoriteIds,
                            userId: widget.profile.id,
                            rsvpService: widget.rsvpService,
                            favoriteService: widget.favoriteService,
                          ),
                          _EventList(
                            events: favorites,
                            emptyText: 'No favorites yet - tap the heart on an event.',
                            favoriteIds: favoriteIds,
                            userId: widget.profile.id,
                            rsvpService: widget.rsvpService,
                            favoriteService: widget.favoriteService,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({
    required this.events,
    required this.emptyText,
    required this.favoriteIds,
    required this.userId,
    required this.rsvpService,
    required this.favoriteService,
  });

  final List<Event> events;
  final String emptyText;
  final Set<String> favoriteIds;
  final String userId;
  final RsvpService rsvpService;
  final FavoriteService favoriteService;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Text(emptyText, style: Theme.of(context).textTheme.bodyMedium),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final isFavorite = favoriteIds.contains(event.id);
        return StaggeredFadeSlide(
          index: index,
          child: EventCard(
            event: event,
            isFavorite: isFavorite,
            onToggleFavorite: () => favoriteService.setFavorite(
              eventId: event.id,
              userId: userId,
              favorited: !isFavorite,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EventDetailScreen(
                  event: event,
                  userId: userId,
                  rsvpService: rsvpService,
                  favoriteService: favoriteService,
                  isFavorite: isFavorite,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
