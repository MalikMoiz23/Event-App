import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/event_index.dart';
import '../../models/ticket.dart';
import '../../models/user_profile.dart';
import '../../services/favorite_service.dart';
import '../../services/ticket_service.dart';
import 'discover_screen.dart';
import 'my_tickets_screen.dart';
import 'profile_screen.dart';
import 'saved_screen.dart';

/// The attendee's four tabs.
///
/// Replaces the previous single screen with a search box, four scrolling tabs
/// and its own theme and sign-out buttons crammed into the app bar. That
/// layout put "Favorites" - a personal list - next to three time filters of
/// the same event feed, and left tickets nowhere to live at all.
///
/// Two things live here rather than inside the tabs:
///
///  * the favourites subscription, because it needs the user id and three of
///    the four tabs read it;
///  * an [IndexedStack], so switching tabs keeps each one's scroll position
///    and its stream subscription instead of tearing them down and starting
///    over on every tap.
class UserShell extends StatefulWidget {
  const UserShell({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final userId = widget.profile.id;

    return MultiProvider(
      providers: [
        StreamProvider<FavoriteIndex>(
          initialData: FavoriteIndex.empty,
          create: (ctx) => ctx
              .read<FavoriteService>()
              .watchFavoriteEventIds(userId)
              .map(FavoriteIndex.new),
        ),
        StreamProvider<List<Ticket>>(
          initialData: const [],
          create: (ctx) => ctx.read<TicketService>().watchMyTickets(userId),
        ),
      ],
      child: Builder(
        builder: (context) {
          final tickets = context.watch<List<Ticket>>();
          final saved = context.watch<FavoriteIndex>();

          // Only tickets that still get you in, and only for events that
          // have not finished, are worth badging - a pile of past tickets is
          // history, not a to-do.
          final liveTickets = tickets.where((t) => t.isActive).length;

          return Scaffold(
            body: IndexedStack(
              index: _index,
              children: [
                DiscoverScreen(profile: widget.profile),
                MyTicketsScreen(profile: widget.profile),
                SavedScreen(profile: widget.profile),
                ProfileScreen(profile: widget.profile),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (next) => setState(() => _index = next),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore_rounded),
                  label: 'Discover',
                ),
                NavigationDestination(
                  icon: _CountBadge(
                    count: liveTickets,
                    child: const Icon(Icons.confirmation_number_outlined),
                  ),
                  selectedIcon: _CountBadge(
                    count: liveTickets,
                    child: const Icon(Icons.confirmation_number_rounded),
                  ),
                  label: 'Tickets',
                ),
                NavigationDestination(
                  icon: _CountBadge(
                    count: saved.count,
                    child: const Icon(Icons.bookmark_outline_rounded),
                  ),
                  selectedIcon: _CountBadge(
                    count: saved.count,
                    child: const Icon(Icons.bookmark_rounded),
                  ),
                  label: 'Saved',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Badge that disappears at zero instead of showing a "0".
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Badge(label: Text(count > 99 ? '99+' : '$count'), child: child);
  }
}
