import 'package:intl/intl.dart';

/// Every date, time and money string in the app comes from here.
///
/// `DateFormat` and `NumberFormat` parse their pattern on construction, so
/// these are built once and shared rather than re-created inside `build`.
/// Keeping them in one place is also what stops the same event rendering as
/// "5 Sep" on one screen and "05/09" on the next.
class Formatters {
  const Formatters._();

  /// "Friday, 5 September 2026 - 7:00 pm"
  static final DateFormat fullDateTime = DateFormat(
    'EEEE, d MMMM yyyy • h:mm a',
  );

  /// "Fri, 5 Sep • 7:00 pm"
  static final DateFormat mediumDateTime = DateFormat('EEE, d MMM • h:mm a');

  /// "5 Sep, 7:00 pm"
  static final DateFormat shortDateTime = DateFormat('d MMM, h:mm a');

  /// "5 September 2026"
  static final DateFormat longDate = DateFormat('d MMMM yyyy');

  /// "5 Sep"
  static final DateFormat dayMonth = DateFormat('d MMM');

  static final DateFormat weekday = DateFormat('EEE');
  static final DateFormat dayOfMonth = DateFormat('d');
  static final DateFormat monthShort = DateFormat('MMM');
  static final DateFormat timeOnly = DateFormat('h:mm a');

  /// Sortable, locale-independent - used for CSV filenames and exports.
  static final DateFormat fileStamp = DateFormat('yyyy-MM-dd_HHmm');
  static final DateFormat csvDateTime = DateFormat('yyyy-MM-dd HH:mm');

  static final NumberFormat _thousands = NumberFormat('#,##0');

  /// Ticket price as shown to an attendee. Zero reads as "Free", not "PKR 0".
  static String price(double amount) =>
      amount <= 0 ? 'Free' : 'PKR ${_thousands.format(amount)}';

  /// Money that is never free, e.g. a revenue total on the admin dashboard.
  static String money(num amount) => 'PKR ${_thousands.format(amount)}';

  static String count(num value) => _thousands.format(value);

  /// A start time relative to now: "in 3 days", "in 20 minutes", "2 days ago".
  ///
  /// Deliberately coarse - the exact timestamp is always shown next to it, so
  /// this only needs to convey nearness.
  static String relativeToNow(DateTime when, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final difference = when.difference(reference);
    final ahead = !difference.isNegative;
    final magnitude = difference.abs();

    final String amount;
    if (magnitude.inMinutes < 1) {
      return 'now';
    } else if (magnitude.inMinutes < 60) {
      amount = _plural(magnitude.inMinutes, 'minute');
    } else if (magnitude.inHours < 24) {
      amount = _plural(magnitude.inHours, 'hour');
    } else if (magnitude.inDays < 7) {
      amount = _plural(magnitude.inDays, 'day');
    } else if (magnitude.inDays < 30) {
      amount = _plural(magnitude.inDays ~/ 7, 'week');
    } else if (magnitude.inDays < 365) {
      amount = _plural(magnitude.inDays ~/ 30, 'month');
    } else {
      amount = _plural(magnitude.inDays ~/ 365, 'year');
    }

    return ahead ? 'in $amount' : '$amount ago';
  }

  /// A duration written out, for "runs for 3 hours" style copy.
  static String span(DateTime start, DateTime end) {
    final minutes = end.difference(start).inMinutes;
    if (minutes < 60) return _plural(minutes, 'minute');
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (hours < 24) {
      return remainder == 0
          ? _plural(hours, 'hour')
          : '${_plural(hours, 'hour')} ${_plural(remainder, 'minute')}';
    }
    return _plural(hours ~/ 24, 'day');
  }

  static String _plural(int value, String noun) =>
      '$value $noun${value == 1 ? '' : 's'}';
}
