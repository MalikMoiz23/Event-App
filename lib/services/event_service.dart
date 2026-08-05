import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/event.dart';

class EventService {
  EventService(this._client);

  final SupabaseClient _client;

  Stream<List<Event>> watchEvents() {
    return _client
        .from('events')
        .stream(primaryKey: ['id'])
        .order('event_date')
        .map((rows) => rows.map(Event.fromMap).toList());
  }

  Future<String> uploadCoverImage({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final path =
        '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    await _client.storage
        .from(SupabaseConfig.eventImagesBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$fileExtension',
            upsert: true,
          ),
        );
    return _client.storage
        .from(SupabaseConfig.eventImagesBucket)
        .getPublicUrl(path);
  }

  Future<void> createEvent({
    required String name,
    required String description,
    required double charges,
    required EventCategory category,
    required String? imageUrl,
    required DateTime eventDate,
    required DateTime endDate,
    required String createdBy,
  }) async {
    await _client.from('events').insert({
      'name': name,
      'description': description,
      'charges': charges,
      'category': category.label,
      'image_url': imageUrl,
      'event_date': eventDate.toUtc().toIso8601String(),
      'end_date': endDate.toUtc().toIso8601String(),
      'created_by': createdBy,
    });
  }

  Future<void> updateEvent({
    required String id,
    required String name,
    required String description,
    required double charges,
    required EventCategory category,
    required String? imageUrl,
    required DateTime eventDate,
    required DateTime endDate,
  }) async {
    await _client.from('events').update({
      'name': name,
      'description': description,
      'charges': charges,
      'category': category.label,
      'image_url': imageUrl,
      'event_date': eventDate.toUtc().toIso8601String(),
      'end_date': endDate.toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteEvent(String id) async {
    await _client.from('events').delete().eq('id', id);
  }
}
