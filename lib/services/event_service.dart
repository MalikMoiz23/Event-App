import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/agenda_item.dart';
import '../models/event.dart';
import '../models/event_draft.dart';
import '../models/event_image.dart';

/// Reads and writes everything under an event: the row itself, its gallery,
/// its running order, and the live attendance counters.
///
/// Reads are exposed as broadcast streams so screens rebuild the instant a
/// row changes. Drafts are filtered out for non-admins by the RLS policy in
/// migration 0001, not here - the client never gets sent them.
class EventService {
  EventService(this._client);

  final SupabaseClient _client;

  Stream<List<Event>> watchEvents() {
    return _client
        .from(SupabaseConfig.eventsTable)
        .stream(primaryKey: ['id'])
        .order('event_date')
        .map((rows) => rows.map(Event.fromMap).toList());
  }

  /// Live seat counts keyed by event id.
  ///
  /// Attendees are not allowed to read other people's ticket rows, so the
  /// aggregate comes from its own table (see migration 0002) which everyone
  /// may read.
  Stream<Map<String, EventStats>> watchStats() {
    return _client
        .from(SupabaseConfig.eventStatsTable)
        .stream(primaryKey: ['event_id'])
        .map(
          (rows) => {
            for (final row in rows)
              row['event_id'] as String: EventStats.fromMap(row),
          },
        );
  }

  Stream<List<EventImage>> watchImages(String eventId) {
    return _client
        .from(SupabaseConfig.eventImagesTable)
        .stream(primaryKey: ['id'])
        .eq('event_id', eventId)
        .order('position')
        .map((rows) => rows.map(EventImage.fromMap).toList());
  }

  Stream<List<AgendaItem>> watchAgenda(String eventId) {
    return _client
        .from(SupabaseConfig.eventAgendaTable)
        .stream(primaryKey: ['id'])
        .eq('event_id', eventId)
        .order('starts_at')
        .map((rows) => rows.map(AgendaItem.fromMap).toList());
  }

  Future<List<AgendaItem>> fetchAgenda(String eventId) async {
    final rows = await _client
        .from(SupabaseConfig.eventAgendaTable)
        .select()
        .eq('event_id', eventId)
        .order('position')
        .order('starts_at');
    return rows.map(AgendaItem.fromMap).toList();
  }

  // --- Images -------------------------------------------------------------

  /// Uploads to the public `event-images` bucket and returns the public URL.
  ///
  /// The path is prefixed with a millisecond timestamp so a re-upload of the
  /// same filename cannot clobber another event's cover.
  Future<String> uploadCoverImage({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final path = '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    await _client.storage
        .from(SupabaseConfig.eventImagesBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeFor(fileExtension),
            upsert: true,
          ),
        );
    return _client.storage
        .from(SupabaseConfig.eventImagesBucket)
        .getPublicUrl(path);
  }

  Future<void> addGalleryImage({
    required String eventId,
    required String imageUrl,
    required int position,
  }) async {
    await _client.from(SupabaseConfig.eventImagesTable).insert({
      'event_id': eventId,
      'image_url': imageUrl,
      'position': position,
    });
  }

  Future<void> removeGalleryImage(String imageId) async {
    await _client
        .from(SupabaseConfig.eventImagesTable)
        .delete()
        .eq('id', imageId);
  }

  // --- Agenda -------------------------------------------------------------

  Future<void> addAgendaItem({
    required String eventId,
    required String title,
    required DateTime startsAt,
    DateTime? endsAt,
    String? speaker,
    int position = 0,
  }) async {
    await _client.from(SupabaseConfig.eventAgendaTable).insert({
      'event_id': eventId,
      'title': title.trim(),
      'speaker': (speaker?.trim().isEmpty ?? true) ? null : speaker!.trim(),
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt?.toUtc().toIso8601String(),
      'position': position,
    });
  }

  Future<void> removeAgendaItem(String itemId) async {
    await _client
        .from(SupabaseConfig.eventAgendaTable)
        .delete()
        .eq('id', itemId);
  }

  // --- Events -------------------------------------------------------------

  /// Returns the created row so the caller can immediately attach gallery
  /// images and agenda items, both of which need the new event's id.
  Future<Event> createEvent(
    EventDraft draft, {
    required String createdBy,
  }) async {
    final row = await _client
        .from(SupabaseConfig.eventsTable)
        .insert({...draft.toColumns(), 'created_by': createdBy})
        .select()
        .single();
    return Event.fromMap(row);
  }

  Future<Event> updateEvent(String id, EventDraft draft) async {
    final row = await _client
        .from(SupabaseConfig.eventsTable)
        .update(draft.toColumns())
        .eq('id', id)
        .select()
        .single();
    return Event.fromMap(row);
  }

  /// Flips an event between draft and published without touching anything
  /// else, for the switch on the admin list.
  Future<void> setPublished({
    required String id,
    required bool published,
  }) async {
    await _client
        .from(SupabaseConfig.eventsTable)
        .update({'is_published': published})
        .eq('id', id);
  }

  Future<void> deleteEvent(String id) async {
    await _client.from(SupabaseConfig.eventsTable).delete().eq('id', id);
  }

  static String _contentTypeFor(String extension) {
    switch (extension.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
        return 'image/heic';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
