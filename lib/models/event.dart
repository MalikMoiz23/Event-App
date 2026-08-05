enum EventCategory { family, kids, corporate, general, vip }

extension EventCategoryX on EventCategory {
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
    );
  }

  final String id;
  final String name;
  final String description;
  final double charges;
  final EventCategory category;
  final String? imageUrl;
  final DateTime eventDate;
  final DateTime endDate;
  final String createdBy;

  bool get isFree => charges <= 0;

  EventStatus statusAt(DateTime now) {
    if (now.isBefore(eventDate)) return EventStatus.upcoming;
    if (now.isAfter(endDate)) return EventStatus.past;
    return EventStatus.ongoing;
  }
}
