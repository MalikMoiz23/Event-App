import 'package:supabase_flutter/supabase_flutter.dart';

class FavoriteService {
  FavoriteService(this._client);

  final SupabaseClient _client;

  /// Emits the current user's favorited event ids every time they change.
  Stream<Set<String>> watchFavoriteEventIds(String userId) {
    return _client
        .from('favorites')
        .stream(primaryKey: ['event_id', 'user_id'])
        .eq('user_id', userId)
        .map((rows) => rows.map((r) => r['event_id'] as String).toSet());
  }

  Future<void> setFavorite({
    required String eventId,
    required String userId,
    required bool favorited,
  }) async {
    if (favorited) {
      await _client.from('favorites').upsert({
        'event_id': eventId,
        'user_id': userId,
      }, onConflict: 'event_id,user_id');
    } else {
      await _client
          .from('favorites')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', userId);
    }
  }
}
