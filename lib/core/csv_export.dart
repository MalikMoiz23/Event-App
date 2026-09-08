import '../models/event.dart';
import '../models/ticket.dart';
import 'formatters.dart';

/// Builds the attendee roster that admins export from an event.
///
/// Written by hand rather than pulled from a package because the only tricky
/// part of RFC 4180 is quoting, and getting that wrong is what turns a name
/// like `Khan, Ali` into two columns in Excel.
class CsvExport {
  const CsvExport._();

  static const List<String> _headers = [
    'Ticket code',
    'Attendee',
    'Email',
    'Status',
    'Booked at',
    'Checked in at',
  ];

  static String roster(List<Ticket> tickets) {
    final rows = <List<String>>[
      _headers,
      for (final ticket in tickets)
        [
          ticket.code,
          ticket.attendeeName ?? '',
          ticket.attendeeEmail ?? '',
          ticket.status.label,
          Formatters.csvDateTime.format(ticket.bookedAt),
          ticket.checkedInAt == null
              ? ''
              : Formatters.csvDateTime.format(ticket.checkedInAt!),
        ],
    ];

    // CRLF, because that is what Excel expects from a .csv on Windows.
    return rows.map((row) => row.map(_field).join(',')).join('\r\n');
  }

  /// `annual-sports-day-attendees-2026-09-08_1430.csv`
  static String fileName(Event event) {
    final slug = event.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final stamp = Formatters.fileStamp.format(DateTime.now());
    return '${slug.isEmpty ? 'event' : slug}-attendees-$stamp.csv';
  }

  /// Quotes only when it has to, and doubles any embedded quote.
  ///
  /// A leading `=`, `+`, `-` or `@` is prefixed with an apostrophe: without
  /// it, a spreadsheet treats the cell as a formula, which is both wrong and
  /// a well-known CSV injection vector.
  static String _field(String value) {
    var text = value;
    if (text.isNotEmpty && '=+-@'.contains(text[0])) {
      text = "'$text";
    }
    final needsQuotes =
        text.contains(',') ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r');
    if (!needsQuotes) return text;
    return '"${text.replaceAll('"', '""')}"';
  }
}
