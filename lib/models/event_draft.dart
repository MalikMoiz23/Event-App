import 'event.dart';

/// The editable shape of an event, as the admin form holds it before it
/// becomes a row.
///
/// Passing one object beats threading eighteen named arguments through
/// `EventService`, and it puts the column-name mapping next to the field list
/// instead of scattering `'venue_name': ...` literals through the service.
class EventDraft {
  const EventDraft({
    required this.name,
    required this.description,
    required this.charges,
    required this.category,
    required this.eventDate,
    required this.endDate,
    this.imageUrl,
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
  });

  /// Seeds the form when editing an existing event.
  factory EventDraft.from(Event event) {
    return EventDraft(
      name: event.name,
      description: event.description,
      charges: event.charges,
      category: event.category,
      eventDate: event.eventDate,
      endDate: event.endDate,
      imageUrl: event.imageUrl,
      venueName: event.venueName,
      venueAddress: event.venueAddress,
      latitude: event.latitude,
      longitude: event.longitude,
      organizerName: event.organizerName,
      organizerPhone: event.organizerPhone,
      organizerEmail: event.organizerEmail,
      capacity: event.capacity,
      tags: event.tags,
      isPublished: event.isPublished,
    );
  }

  final String name;
  final String description;
  final double charges;
  final EventCategory category;
  final DateTime eventDate;
  final DateTime endDate;
  final String? imageUrl;
  final String? venueName;
  final String? venueAddress;
  final double? latitude;
  final double? longitude;
  final String? organizerName;
  final String? organizerPhone;
  final String? organizerEmail;
  final int? capacity;
  final List<String> tags;
  final bool isPublished;

  /// Column map shared by insert and update. Timestamps go over the wire as
  /// UTC so the database stores an unambiguous instant.
  Map<String, dynamic> toColumns() {
    return {
      'name': name.trim(),
      'description': description.trim(),
      'charges': charges,
      'category': category.label,
      'image_url': imageUrl,
      'event_date': eventDate.toUtc().toIso8601String(),
      'end_date': endDate.toUtc().toIso8601String(),
      'venue_name': _orNull(venueName),
      'venue_address': _orNull(venueAddress),
      'latitude': latitude,
      'longitude': longitude,
      'organizer_name': _orNull(organizerName),
      'organizer_phone': _orNull(organizerPhone),
      'organizer_email': _orNull(organizerEmail),
      'capacity': capacity,
      'tags': tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
      'is_published': isPublished,
    };
  }

  /// An empty text field should clear the column, not store `''`.
  static String? _orNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
