/// What actually goes into a ticket's QR code.
///
/// The payload is the code behind a scheme prefix - `HITEVO:HIT-4F2A-9C13` -
/// rather than the bare code, so the gate scanner can reject a random QR
/// (a wifi config, a product barcode, someone's boarding pass) without a
/// round trip to the database. Without the prefix every stray scan becomes a
/// "no ticket matches this code" error, which trains the person on the gate
/// to ignore the message that matters.
class TicketCode {
  const TicketCode._();

  static const String scheme = 'HITEVO';

  /// The string encoded into the QR image on the pass.
  static String encode(String code) => '$scheme:${code.toUpperCase()}';

  /// Pulls a ticket code out of a scan, or returns null if this is not one
  /// of ours.
  ///
  /// A bare `HIT-...` is also accepted, because that is what someone types
  /// when a phone screen is too cracked or too dim to scan.
  static String? tryParse(String raw) {
    final value = raw.trim().toUpperCase();
    if (value.isEmpty) return null;

    final withoutScheme = value.startsWith('$scheme:')
        ? value.substring(scheme.length + 1)
        : value;

    return _pattern.hasMatch(withoutScheme) ? withoutScheme : null;
  }

  /// Matches the format produced by `new_ticket_code()`: `HIT-` then two
  /// four-character hex groups.
  static final RegExp _pattern = RegExp(r'^HIT-[0-9A-F]{4}-[0-9A-F]{4}$');
}
