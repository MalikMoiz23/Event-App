/// Supabase project credentials and table names.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = 'https://xdrwxmjieygsktmvebkm.supabase.co';

  /// Dashboard -> Project Settings -> API. Either the legacy "anon public"
  /// JWT or the newer "publishable" key works here - supabase_flutter accepts
  /// both under this same parameter.
  ///
  /// The key is safe to ship inside a compiled app: it only grants what the
  /// Row Level Security policies in supabase/ allow. It is still supplied at
  /// build time rather than committed, so rotating it never means rewriting
  /// git history.
  ///
  /// ```sh
  ///   flutter run --dart-define=SUPABASE_PUBLISHABLE_KEY=your_key_here
  /// ```
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static const String eventImagesBucket = 'event-images';

  // Table and function names, so a typo shows up in one place rather than
  // as a runtime 404 from a random screen.
  static const String profilesTable = 'profiles';
  static const String eventsTable = 'events';
  static const String eventImagesTable = 'event_images';
  static const String eventAgendaTable = 'event_agenda';
  static const String ticketsTable = 'tickets';
  static const String eventStatsTable = 'event_ticket_stats';
  static const String favoritesTable = 'favorites';

  static const String bookTicketFn = 'book_ticket';
  static const String cancelTicketFn = 'cancel_ticket';
  static const String checkInTicketFn = 'check_in_ticket';
  static const String revertCheckInFn = 'revert_check_in';
}
