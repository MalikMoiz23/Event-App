import 'event.dart';

enum PriceFilter {
  any('Any price'),
  free('Free only'),
  paid('Paid only');

  const PriceFilter(this.label);

  final String label;
}

enum EventSort {
  soonest('Starting soonest'),
  latest('Starting last'),
  cheapest('Cheapest first'),
  dearest('Most expensive first'),
  popular('Most booked');

  const EventSort(this.label);

  final String label;
}

/// The complete set of criteria behind the Discover list.
///
/// Immutable so a screen can hold one in state and swap it wholesale with
/// [copyWith]; filtering and sorting live here rather than in the widget so
/// the rules stay in one readable place.
class EventFilter {
  const EventFilter({
    this.query = '',
    this.categories = const {},
    this.tags = const {},
    this.price = PriceFilter.any,
    this.from,
    this.to,
    this.sort = EventSort.soonest,
    this.hideSoldOut = false,
  });

  static const EventFilter none = EventFilter();

  final String query;
  final Set<EventCategory> categories;
  final Set<String> tags;
  final PriceFilter price;
  final DateTime? from;
  final DateTime? to;
  final EventSort sort;
  final bool hideSoldOut;

  EventFilter copyWith({
    String? query,
    Set<EventCategory>? categories,
    Set<String>? tags,
    PriceFilter? price,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
    EventSort? sort,
    bool? hideSoldOut,
  }) {
    return EventFilter(
      query: query ?? this.query,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      price: price ?? this.price,
      from: clearDates ? null : (from ?? this.from),
      to: clearDates ? null : (to ?? this.to),
      sort: sort ?? this.sort,
      hideSoldOut: hideSoldOut ?? this.hideSoldOut,
    );
  }

  /// Everything except the free-text query, which has its own affordance in
  /// the search field and should not light up the filter button.
  int get activeCriteriaCount {
    var count = 0;
    if (categories.isNotEmpty) count++;
    if (tags.isNotEmpty) count++;
    if (price != PriceFilter.any) count++;
    if (from != null || to != null) count++;
    if (sort != EventSort.soonest) count++;
    if (hideSoldOut) count++;
    return count;
  }

  bool get isClear => activeCriteriaCount == 0 && query.trim().isEmpty;

  /// Filters then sorts. [seatsTaken] supplies the live booking count per
  /// event id, needed by [hideSoldOut] and [EventSort.popular]; pass an empty
  /// map before the counters have loaded.
  List<Event> apply(
    List<Event> events, {
    Map<String, int> seatsTaken = const {},
  }) {
    final needle = query.trim().toLowerCase();

    final matched = events.where((event) {
      if (needle.isNotEmpty && !_matchesText(event, needle)) return false;
      if (categories.isNotEmpty && !categories.contains(event.category)) {
        return false;
      }
      if (tags.isNotEmpty && !event.tags.any(tags.contains)) return false;

      switch (price) {
        case PriceFilter.free:
          if (!event.isFree) return false;
        case PriceFilter.paid:
          if (event.isFree) return false;
        case PriceFilter.any:
          break;
      }

      // Overlap test, not containment: an event that starts before the window
      // but is still running inside it is a match.
      if (from != null && event.endDate.isBefore(from!)) return false;
      if (to != null && event.eventDate.isAfter(to!)) return false;

      if (hideSoldOut && event.isSoldOut(seatsTaken[event.id] ?? 0)) {
        return false;
      }
      return true;
    }).toList();

    matched.sort((a, b) => _compare(a, b, seatsTaken));
    return matched;
  }

  bool _matchesText(Event event, String needle) {
    return event.name.toLowerCase().contains(needle) ||
        event.description.toLowerCase().contains(needle) ||
        (event.venueLine?.toLowerCase().contains(needle) ?? false) ||
        event.category.label.toLowerCase().contains(needle) ||
        event.tags.any((t) => t.toLowerCase().contains(needle));
  }

  int _compare(Event a, Event b, Map<String, int> seatsTaken) {
    switch (sort) {
      case EventSort.soonest:
        return a.eventDate.compareTo(b.eventDate);
      case EventSort.latest:
        return b.eventDate.compareTo(a.eventDate);
      case EventSort.cheapest:
        return a.charges.compareTo(b.charges);
      case EventSort.dearest:
        return b.charges.compareTo(a.charges);
      case EventSort.popular:
        final byBookings = (seatsTaken[b.id] ?? 0).compareTo(
          seatsTaken[a.id] ?? 0,
        );
        // Ties on an unbooked list would otherwise come back in row order.
        return byBookings != 0
            ? byBookings
            : a.eventDate.compareTo(b.eventDate);
    }
  }
}
