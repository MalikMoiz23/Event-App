/// Lifecycle of a booking. The strings must match the `status` check
/// constraint in supabase/migrations/0002_ticketing.sql.
enum TicketStatus {
  confirmed('confirmed'),
  waitlisted('waitlisted'),
  cancelled('cancelled'),
  checkedIn('checked_in');

  const TicketStatus(this.wireName);

  final String wireName;

  static TicketStatus fromWire(String value) {
    return TicketStatus.values.firstWhere(
      (s) => s.wireName == value,
      orElse: () => TicketStatus.confirmed,
    );
  }

  String get label => switch (this) {
    TicketStatus.confirmed => 'Confirmed',
    TicketStatus.waitlisted => 'Waitlisted',
    TicketStatus.cancelled => 'Cancelled',
    TicketStatus.checkedIn => 'Checked in',
  };

  /// A ticket that still entitles the holder to a seat.
  bool get isActive =>
      this == TicketStatus.confirmed || this == TicketStatus.checkedIn;
}

/// One person's booking for one event. Mirrors `public.tickets`.
///
/// There is at most one row per (event, user); cancelling flips the status
/// rather than deleting, so a re-booking keeps the same [code].
class Ticket {
  const Ticket({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.code,
    required this.status,
    required this.bookedAt,
    this.cancelledAt,
    this.checkedInAt,
    this.checkedInBy,
    this.attendeeName,
    this.attendeeEmail,
  });

  factory Ticket.fromMap(Map<String, dynamic> map) {
    // Admin queries join the holder's profile in as a nested object.
    final profile = map['profiles'];
    final joined = profile is Map<String, dynamic> ? profile : null;

    return Ticket(
      id: map['id'] as String,
      eventId: map['event_id'] as String,
      userId: map['user_id'] as String,
      code: map['code'] as String,
      status: TicketStatus.fromWire(map['status'] as String),
      bookedAt: DateTime.parse(map['booked_at'] as String).toLocal(),
      cancelledAt: _parseOptional(map['cancelled_at']),
      checkedInAt: _parseOptional(map['checked_in_at']),
      checkedInBy: map['checked_in_by'] as String?,
      attendeeName: joined?['full_name'] as String?,
      attendeeEmail: joined?['email'] as String?,
    );
  }

  static DateTime? _parseOptional(Object? value) =>
      value is String ? DateTime.parse(value).toLocal() : null;

  final String id;
  final String eventId;
  final String userId;

  /// Human-readable and encoded into the QR pass, e.g. `HIT-4F2A-9C13`.
  final String code;
  final TicketStatus status;
  final DateTime bookedAt;
  final DateTime? cancelledAt;
  final DateTime? checkedInAt;
  final String? checkedInBy;

  /// Only populated on the admin roster, where the profile row is joined in.
  final String? attendeeName;
  final String? attendeeEmail;

  bool get isActive => status.isActive;
  bool get isCheckedIn => status == TicketStatus.checkedIn;
}

/// Outcome of scanning a code at the gate - the shape returned by the
/// `check_in_ticket` database function.
enum CheckInVerdict {
  ok('ok'),
  alreadyCheckedIn('already_checked_in'),
  cancelled('cancelled'),
  waitlisted('waitlisted'),
  notFound('not_found'),
  reverted('reverted');

  const CheckInVerdict(this.wireName);

  final String wireName;

  static CheckInVerdict fromWire(String? value) {
    return CheckInVerdict.values.firstWhere(
      (v) => v.wireName == value,
      orElse: () => CheckInVerdict.notFound,
    );
  }
}

class CheckInResult {
  const CheckInResult({
    required this.verdict,
    required this.code,
    this.eventName,
    this.eventDate,
    this.attendeeName,
    this.checkedInAt,
  });

  factory CheckInResult.fromMap(Map<String, dynamic> map) {
    return CheckInResult(
      verdict: CheckInVerdict.fromWire(map['verdict'] as String?),
      code: map['code'] as String? ?? '',
      eventName: map['event_name'] as String?,
      eventDate: map['event_date'] is String
          ? DateTime.parse(map['event_date'] as String).toLocal()
          : null,
      attendeeName: map['attendee_name'] as String?,
      checkedInAt: map['checked_in_at'] is String
          ? DateTime.parse(map['checked_in_at'] as String).toLocal()
          : null,
    );
  }

  final CheckInVerdict verdict;
  final String code;
  final String? eventName;
  final DateTime? eventDate;
  final String? attendeeName;
  final DateTime? checkedInAt;

  bool get admitted => verdict == CheckInVerdict.ok;

  String get headline => switch (verdict) {
    CheckInVerdict.ok => 'Admitted',
    CheckInVerdict.alreadyCheckedIn => 'Already used',
    CheckInVerdict.cancelled => 'Cancelled ticket',
    CheckInVerdict.waitlisted => 'On the waitlist',
    CheckInVerdict.notFound => 'Unknown code',
    CheckInVerdict.reverted => 'Check-in undone',
  };

  String get detail => switch (verdict) {
    CheckInVerdict.ok => 'Let them through.',
    CheckInVerdict.alreadyCheckedIn =>
      'This pass was already scanned. Check for a duplicate.',
    CheckInVerdict.cancelled =>
      'The holder cancelled this booking. Do not admit.',
    CheckInVerdict.waitlisted =>
      'No seat was confirmed. Admit only if space has opened up.',
    CheckInVerdict.notFound => 'No ticket matches this code.',
    CheckInVerdict.reverted => 'The pass can be scanned again.',
  };
}
