import 'event.dart';

/// Live seat counts for every event, keyed by id.
///
/// Wrapped in a named type rather than passed around as a bare
/// `Map<String, EventStats>` so it can be handed to a `StreamProvider` and
/// read with `context.watch<EventStatsIndex>()`. Providing a raw generic map
/// works but makes the lookup type ambiguous the moment a second map-shaped
/// value shows up in the tree.
class EventStatsIndex {
  const EventStatsIndex(this._byEventId);

  static const EventStatsIndex empty = EventStatsIndex({});

  final Map<String, EventStats> _byEventId;

  EventStats of(String eventId) =>
      _byEventId[eventId] ?? EventStats(eventId: eventId);

  int seatsTakenOf(String eventId) => of(eventId).seatsTaken;

  /// Flat id -> seats map, the shape [EventFilter.apply] wants.
  Map<String, int> get seatsTaken => {
    for (final entry in _byEventId.entries) entry.key: entry.value.seatsTaken,
  };

  int get totalSeatsTaken =>
      _byEventId.values.fold(0, (sum, s) => sum + s.seatsTaken);

  int get totalCheckedIn =>
      _byEventId.values.fold(0, (sum, s) => sum + s.checkedIn);

  int get totalWaitlisted =>
      _byEventId.values.fold(0, (sum, s) => sum + s.waitlisted);
}

/// The signed-in user's saved event ids.
class FavoriteIndex {
  const FavoriteIndex(this.eventIds);

  static const FavoriteIndex empty = FavoriteIndex({});

  final Set<String> eventIds;

  bool contains(String eventId) => eventIds.contains(eventId);

  int get count => eventIds.length;
}
