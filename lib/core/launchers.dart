import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/agenda_item.dart';
import '../models/event.dart';
import 'calendar_export.dart';
import 'formatters.dart';

/// Hands an event off to another app: maps, dialler, mail, the share sheet,
/// or a calendar.
///
/// Every method returns a bool rather than throwing or showing its own
/// message, so the calling screen decides what a failure looks like. They can
/// all fail for ordinary reasons - a tablet with no dialler, a device with no
/// maps app - and none of those is an error worth a red banner.
class Launchers {
  const Launchers._();

  /// Opens the venue in whatever maps app the device has.
  ///
  /// Coordinates are preferred when the admin supplied them, since a pin is
  /// exact; otherwise this falls back to a text search on the address, which
  /// is the best that can be done with "Officers Mess, HIT Taxila".
  static Future<bool> openMap({
    double? latitude,
    double? longitude,
    String? query,
  }) async {
    final candidates = <Uri>[];

    if (latitude != null && longitude != null) {
      final label = Uri.encodeComponent(query ?? 'Event venue');
      if (!kIsWeb && Platform.isIOS) {
        candidates.add(Uri.parse('maps:0,0?q=$label@$latitude,$longitude'));
      } else {
        // geo: with a q= label drops a named pin; without it some apps just
        // centre the map and show nothing.
        candidates.add(
          Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude($label)'),
        );
      }
      candidates.add(
        Uri.parse(
          'https://www.google.com/maps/search/?api=1'
          '&query=$latitude%2C$longitude',
        ),
      );
    } else if (query != null && query.trim().isNotEmpty) {
      final encoded = Uri.encodeComponent(query.trim());
      candidates.add(
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded'),
      );
    }

    for (final uri in candidates) {
      if (await _tryLaunch(uri)) return true;
    }
    return false;
  }

  static Future<bool> dial(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return Future.value(false);
    return _tryLaunch(Uri(scheme: 'tel', path: cleaned));
  }

  static Future<bool> email(String address, {String? subject}) {
    return _tryLaunch(
      Uri(
        scheme: 'mailto',
        path: address.trim(),
        queryParameters: subject == null ? null : {'subject': subject},
      ),
    );
  }

  /// Shares the event as text.
  static Future<void> shareEvent(Event event) {
    final lines = <String>[
      event.name,
      Formatters.fullDateTime.format(event.eventDate),
      if (event.venueLine != null) event.venueLine!,
      event.isFree ? 'Free entry' : Formatters.money(event.charges),
      '',
      event.description,
      '',
      'via HIT EVO',
    ];
    return SharePlus.instance.share(
      ShareParams(subject: event.name, text: lines.join('\n')),
    );
  }

  /// Writes an .ics file to the temp directory and opens the share sheet so
  /// the user can add it to whichever calendar they use.
  ///
  /// Going via the share sheet rather than a calendar plugin keeps this to
  /// one dependency and works with Google Calendar, Outlook and Apple
  /// Calendar without asking for a calendar-write permission.
  static Future<bool> addToCalendar(
    Event event, {
    List<AgendaItem> agenda = const [],
  }) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/${CalendarExport.fileName(event)}');
      await file.writeAsString(
        CalendarExport.buildIcs(event, agenda: agenda),
        flush: true,
      );
      await SharePlus.instance.share(
        ShareParams(
          subject: event.name,
          text: 'Add "${event.name}" to your calendar',
          files: [XFile(file.path, mimeType: 'text/calendar')],
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Shares a file that has already been written, e.g. an exported roster.
  static Future<bool> shareFile({
    required String path,
    required String mimeType,
    String? subject,
    String? text,
  }) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          subject: subject,
          text: text,
          files: [XFile(path, mimeType: mimeType)],
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Writes [contents] to a temp file and shares it.
  static Future<bool> shareText({
    required String fileName,
    required String contents,
    required String mimeType,
    String? subject,
    String? text,
  }) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(contents, flush: true);
      return shareFile(
        path: file.path,
        mimeType: mimeType,
        subject: subject,
        text: text,
      );
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _tryLaunch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
