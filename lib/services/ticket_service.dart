import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/ticket.dart';

/// Raised when the database refuses a booking, carrying the message the
/// `book_ticket` / `cancel_ticket` functions raised.
///
/// Those messages are written for humans ("That event has already
/// finished."), so the UI can show them verbatim instead of inventing its own
/// copy for every failure mode.
class TicketException implements Exception {
  const TicketException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Booking, cancelling and gate check-in.
///
/// Every write goes through a database function rather than a table write:
/// capacity has to be evaluated under a row lock, so a client-side
/// "count then insert" would oversell an event under any real concurrency.
/// `public.tickets` has no INSERT/UPDATE policy at all, which makes that
/// rule enforced rather than merely intended.
class TicketService {
  TicketService(this._client);

  final SupabaseClient _client;

  /// Every ticket belonging to [userId], newest booking first.
  Stream<List<Ticket>> watchMyTickets(String userId) {
    return _client
        .from(SupabaseConfig.ticketsTable)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('booked_at', ascending: false)
        .map((rows) => rows.map(Ticket.fromMap).toList());
  }

  /// The caller's ticket for one event, or `null` if they have never booked.
  /// A cancelled booking still emits a row - the UI needs to know the
  /// difference between "cancelled" and "never booked".
  Stream<Ticket?> watchMyTicketFor({
    required String eventId,
    required String userId,
  }) {
    return _client
        .from(SupabaseConfig.ticketsTable)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) {
          for (final row in rows) {
            if (row['event_id'] == eventId) return Ticket.fromMap(row);
          }
          return null;
        });
  }

  /// Admin only: the full attendee list for one event, with holder names
  /// joined in. Ordinary users get an empty list back - the RLS policy hides
  /// rows that are not theirs.
  Future<List<Ticket>> fetchRoster(String eventId) async {
    final rows = await _client
        .from(SupabaseConfig.ticketsTable)
        .select('*, ${SupabaseConfig.profilesTable}(full_name, email)')
        .eq('event_id', eventId)
        .order('booked_at');
    return rows.map(Ticket.fromMap).toList();
  }

  /// Admin only: every ticket across every event, for the analytics screen.
  Stream<List<Ticket>> watchAllTickets() {
    return _client
        .from(SupabaseConfig.ticketsTable)
        .stream(primaryKey: ['id'])
        .map((rows) => rows.map(Ticket.fromMap).toList());
  }

  /// Confirms a seat, or joins the waitlist when the event is full.
  ///
  /// Returns the resulting ticket so the caller can tell the user which of
  /// the two happened.
  Future<Ticket> book(String eventId) async {
    try {
      final row = await _client.rpc(
        SupabaseConfig.bookTicketFn,
        params: {'p_event_id': eventId},
      );
      if (row is Map<String, dynamic>) return Ticket.fromMap(row);
      throw const TicketException('The booking did not go through.');
    } on PostgrestException catch (e) {
      throw TicketException(e.message);
    }
  }

  /// Releases the seat and promotes the longest-waiting person on the
  /// waitlist, if the event has a capacity.
  Future<void> cancel(String eventId) async {
    try {
      await _client.rpc(
        SupabaseConfig.cancelTicketFn,
        params: {'p_event_id': eventId},
      );
    } on PostgrestException catch (e) {
      throw TicketException(e.message);
    }
  }

  /// Admin only. Never throws for a bad ticket - an unknown or already-used
  /// code comes back as a verdict so the scanner can show a red card rather
  /// than an error dialog.
  Future<CheckInResult> checkIn(String code) async {
    try {
      final row = await _client.rpc(
        SupabaseConfig.checkInTicketFn,
        params: {'p_code': code},
      );
      if (row is Map<String, dynamic>) return CheckInResult.fromMap(row);
      throw const TicketException('The scanner got an unexpected response.');
    } on PostgrestException catch (e) {
      throw TicketException(e.message);
    }
  }

  /// Undoes a mis-scan so the pass can be used again.
  Future<CheckInResult> revertCheckIn(String code) async {
    try {
      final row = await _client.rpc(
        SupabaseConfig.revertCheckInFn,
        params: {'p_code': code},
      );
      if (row is Map<String, dynamic>) return CheckInResult.fromMap(row);
      throw const TicketException('The undo got an unexpected response.');
    } on PostgrestException catch (e) {
      throw TicketException(e.message);
    }
  }
}
