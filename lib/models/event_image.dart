/// One extra photo attached to an event, beyond its cover image.
///
/// Mirrors `public.event_images`. Ordered by [position] so an admin can
/// arrange the gallery rather than being stuck with upload order.
class EventImage {
  const EventImage({
    required this.id,
    required this.eventId,
    required this.imageUrl,
    required this.position,
  });

  factory EventImage.fromMap(Map<String, dynamic> map) {
    return EventImage(
      id: map['id'] as String,
      eventId: map['event_id'] as String,
      imageUrl: map['image_url'] as String,
      position: (map['position'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String eventId;
  final String imageUrl;
  final int position;
}
