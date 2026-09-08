enum EventCategory { family, kids, corporate, general, vip }

extension EventCategoryX on EventCategory {
  /// Must match the `category` check constraint in supabase/schema.sql.
  String get label {
    switch (this) {
      case EventCategory.family:
        return 'Family';
      case EventCategory.kids:
        return 'Kids';
      case EventCategory.corporate:
        return 'Corporate';
      case EventCategory.general:
        return 'General';
      case EventCategory.vip:
        return 'VIP';
    }
  }

  static EventCategory fromLabel(String label) {
    return EventCategory.values.firstWhere(
      (c) => c.label == label,
      orElse: () => EventCategory.general,
    );
  }
}

enum EventStatus { upcoming, ongoing, past }

extension EventStatusX on EventStatus {
  String get label => switch (this) {
    EventStatus.upcoming => 'Upcoming',
    EventStatus.ongoing => 'Happening now',
    EventStatus.past => 'Finished',
  };
}

class Event {
  const Event({
    required this.id,
    required this.name,
    required this.description,
    required this.charges,
    required this.category,
    required this.imageUrl,
    required this.eventDate,
    required this.endDate,
    required this.createdBy,
    this.venueName,
    this.venueAddress,
    this.latitude,
    this.longitude,
    this.organizerName,
    this.organizerPhone,
    this.organizerEmail,
    this.capacity,
    this.tags = const [],
    this.isPublished = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      charges: (map['charges'] as num).toDouble(),
      category: EventCategoryX.fromLabel(map['category'] as String),
      imageUrl: map['image_url'] as String?,
      eventDate: DateTime.parse(map['event_date'] as String).toLocal(),
      endDate: DateTime.parse(map['end_date'] as String).toLocal(),
      createdBy: map['created_by'] as String,
      venueName: map['venue_name'] as String?,
      venueAddress: map['venue_address'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      organizerName: map['organizer_name'] as String?,
      organizerPhone: map['organizer_phone'] as String?,
      organizerEmail: map['organizer_email'] as String?,
      capacity: (map['capacity'] as num?)?.toInt(),
      // Postgres text[] arrives as List<dynamic>.
      tags:
          (map['tags'] as List?)
              ?.map((t) => t.toString())
              .where((t) => t.isNotEmpty)
              .toList(growable: false) ??
          const [],
      // Defaults keep the model usable against a database that has not had
      // migration 0001 applied yet.
      isPublished: map['is_published'] as bool? ?? true,
      createdAt: _parseOptional(map['created_at']),
      updatedAt: _parseOptional(map['updated_at']),
    );
  }

  static DateTime? _parseOptional(Object? value) =>
      value is String ? DateTime.parse(value).toLocal() : null;

  final String id;
  final String name;
  final String description;
  final double charges;
  final EventCategory category;
  final String? imageUrl;
  final DateTime eventDate;
  final DateTime endDate;
  final String createdBy;

  final String? venueName;
  final String? venueAddress;
  final double? latitude;
  final double? longitude;

  final String? organizerName;
  final String? organizerPhone;
  final String? organizerEmail;

  /// `null` means unlimited seats.
  final int? capacity;
  final List<String> tags;

  /// Drafts are visible to admins only - enforced by RLS, not by the client.
  final bool isPublished;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isFree => charges <= 0;
  bool get isLimited => capacity != null;

  bool get hasVenue => (venueName ?? venueAddress)?.trim().isNotEmpty ?? false;
  bool get hasCoordinates => latitude != null && longitude != null;
  bool get hasOrganizerContact =>
      (organizerPhone?.trim().isNotEmpty ?? false) ||
      (organizerEmail?.trim().isNotEmpty ?? false);

  /// Best single-line description of where this happens.
  String? get venueLine {
    final name = venueName?.trim();
    final address = venueAddress?.trim();
    if (name != null &&
        name.isNotEmpty &&
        address != null &&
        address.isNotEmpty) {
      return '$name, $address';
    }
    if (name != null && name.isNotEmpty) return name;
    if (address != null && address.isNotEmpty) return address;
    return null;
  }

  EventStatus statusAt(DateTime now) {
    if (now.isBefore(eventDate)) return EventStatus.upcoming;
    if (now.isAfter(endDate)) return EventStatus.past;
    return EventStatus.ongoing;
  }

  bool get isBookable {
    final now = DateTime.now();
    return isPublished && endDate.isAfter(now);
  }

  /// How many seats are left given the live counter, or `null` when the event
  /// has no capacity limit.
  int? seatsLeft(int seatsTaken) {
    final limit = capacity;
    if (limit == null) return null;
    final left = limit - seatsTaken;
    return left < 0 ? 0 : left;
  }

  bool isSoldOut(int seatsTaken) => (seatsLeft(seatsTaken) ?? 1) <= 0;

  /// 0.0 - 1.0, for a capacity meter. `null` when unlimited.
  double? fillRatio(int seatsTaken) {
    final limit = capacity;
    if (limit == null || limit == 0) return null;
    return (seatsTaken / limit).clamp(0.0, 1.0);
  }
}

/// Live attendance counters for one event, mirrored from
/// `public.event_ticket_stats` so attendees can see how full an event is
/// without being able to read other people's ticket rows.
class EventStats {
  const EventStats({
    required this.eventId,
    this.seatsTaken = 0,
    this.waitlisted = 0,
    this.checkedIn = 0,
  });

  factory EventStats.fromMap(Map<String, dynamic> map) {
    return EventStats(
      eventId: map['event_id'] as String,
      seatsTaken: (map['seats_taken'] as num?)?.toInt() ?? 0,
      waitlisted: (map['waitlisted'] as num?)?.toInt() ?? 0,
      checkedIn: (map['checked_in'] as num?)?.toInt() ?? 0,
    );
  }

  static const EventStats empty = EventStats(eventId: '');

  final String eventId;
  final int seatsTaken;
  final int waitlisted;
  final int checkedIn;

  int get notYetArrived => seatsTaken - checkedIn;
}
