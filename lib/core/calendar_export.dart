import '../models/agenda_item.dart';
import '../models/event.dart';

/// Turns an event into an iCalendar (.ics) document so an attendee can drop it
/// into Google Calendar, Outlook or Apple Calendar.
///
/// RFC 5545 is fussy in three ways that are easy to get wrong, so all three
/// are handled here rather than at the call site:
///
///  * lines are separated by CRLF, never a bare LF;
///  * a content line longer than 75 octets must be folded onto a continuation
///    line beginning with a single space;
///  * `\`, `;`, `,` and newlines inside a text value must be escaped.
class CalendarExport {
  const CalendarExport._();

  static const String _productId = '-//HIT EVO//Events//EN';
  static const String _crlf = '\r\n';

  static String buildIcs(Event event, {List<AgendaItem> agenda = const []}) {
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:$_productId',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      ..._vevent(event, agenda: agenda),
      'END:VCALENDAR',
    ];
    return lines.map(_fold).join(_crlf) + _crlf;
  }

  /// A filename safe on every platform: `hit-evo-annual-sports-day.ics`.
  static String fileName(Event event) {
    final slug = event.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return 'hit-evo-${slug.isEmpty ? event.id : slug}.ics';
  }

  static List<String> _vevent(Event event, {required List<AgendaItem> agenda}) {
    final description = StringBuffer(event.description.trim());
    if (agenda.isNotEmpty) {
      description.write('\n\nRunning order:');
      for (final item in agenda) {
        description.write('\n- ${_timeOfDay(item.startsAt)}  ${item.title}');
        if (item.hasSpeaker) description.write(' (${item.speaker})');
      }
    }
    description.write(
      event.isFree
          ? '\n\nEntry: free'
          : '\n\nEntry: PKR ${event.charges.toStringAsFixed(0)}',
    );

    return [
      'BEGIN:VEVENT',
      'UID:${event.id}@hit-evo',
      'DTSTAMP:${_utcStamp(DateTime.now())}',
      'DTSTART:${_utcStamp(event.eventDate)}',
      'DTEND:${_utcStamp(event.endDate)}',
      'SUMMARY:${_escape(event.name)}',
      'DESCRIPTION:${_escape(description.toString())}',
      if (event.venueLine != null) 'LOCATION:${_escape(event.venueLine!)}',
      if (event.hasCoordinates) 'GEO:${event.latitude};${event.longitude}',
      'CATEGORIES:${_escape(event.category.label)}',
      'STATUS:CONFIRMED',
      if (event.organizerName != null)
        'ORGANIZER;CN=${_escape(event.organizerName!)}:'
            'mailto:${event.organizerEmail ?? 'noreply@hit-evo.local'}',
      'END:VEVENT',
    ];
  }

  /// iCalendar timestamps are UTC with a trailing Z: `20260910T140000Z`.
  static String _utcStamp(DateTime local) {
    final utc = local.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${utc.year}${two(utc.month)}${two(utc.day)}'
        'T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }

  static String _timeOfDay(DateTime when) {
    final hour = when.hour % 12 == 0 ? 12 : when.hour % 12;
    final minute = when.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${when.hour < 12 ? 'am' : 'pm'}';
  }

  /// Backslash first, otherwise the escapes added below get escaped again.
  static String _escape(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll(';', '\\;')
        .replaceAll(',', '\\,')
        .replaceAll('\r\n', '\\n')
        .replaceAll('\n', '\\n');
  }

  /// Folds a content line to 75 octets, continuing with a leading space.
  static String _fold(String line) {
    if (line.length <= 75) return line;
    final buffer = StringBuffer(line.substring(0, 75));
    var index = 75;
    while (index < line.length) {
      final end = (index + 74).clamp(0, line.length);
      buffer
        ..write(_crlf)
        ..write(' ')
        ..write(line.substring(index, end));
      index = end;
    }
    return buffer.toString();
  }
}
