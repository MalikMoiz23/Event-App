/// A single slot in an event's running order - a talk, a break, a prize
/// ceremony. Mirrors `public.event_agenda`.
class AgendaItem {
  const AgendaItem({
    required this.id,
    required this.eventId,
    required this.title,
    required this.startsAt,
    this.speaker,
    this.endsAt,
    this.position = 0,
  });

  factory AgendaItem.fromMap(Map<String, dynamic> map) {
    return AgendaItem(
      id: map['id'] as String,
      eventId: map['event_id'] as String,
      title: map['title'] as String,
      speaker: map['speaker'] as String?,
      startsAt: DateTime.parse(map['starts_at'] as String).toLocal(),
      endsAt: map['ends_at'] is String
          ? DateTime.parse(map['ends_at'] as String).toLocal()
          : null,
      position: (map['position'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String eventId;
  final String title;
  final String? speaker;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int position;

  bool get hasSpeaker => speaker?.trim().isNotEmpty ?? false;

  bool isCurrentAt(DateTime now) {
    if (now.isBefore(startsAt)) return false;
    final end = endsAt;
    return end == null ? false : now.isBefore(end);
  }
}
