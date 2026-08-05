import 'package:supabase_flutter/supabase_flutter.dart';

class RsvpService {
  RsvpService(this._client);

  final SupabaseClient _client;

  /// Emits the list of user ids RSVP'd to [eventId] every time it changes.
  Stream<List<String>> watchAttendees(String eventId) {
    return _client
        .from('rsvps')
        .stream(primaryKey: ['id'])
        .eq('event_id', eventId)
        .map((rows) => rows.map((r) => r['user_id'] as String).toList());
  }

  /// Every RSVP's event id, across all events - for admin analytics.
  Stream<List<String>> watchAllEventIds() {
    return _client
        .from('rsvps')
        .stream(primaryKey: ['id'])
        .map((rows) => rows.map((r) => r['event_id'] as String).toList());
  }

  Future<void> setGoing({
    required String eventId,
    required String userId,
    required bool going,
  }) async {
    if (going) {
      await _client.from('rsvps').upsert({
        'event_id': eventId,
        'user_id': userId,
      }, onConflict: 'event_id,user_id');
    } else {
      await _client
          .from('rsvps')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', userId);
    }
  }
}
