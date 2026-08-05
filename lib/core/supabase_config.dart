/// Supabase project credentials.
///
/// The anon key is safe to ship in a compiled app (it only grants what
/// Row Level Security policies in supabase/schema.sql allow) but must still
/// be filled in below before running the app.
class SupabaseConfig {
  static const String url = 'https://xdrwxmjieygsktmvebkm.supabase.co';

  /// Dashboard -> Project Settings -> API. Either the legacy "anon public"
  /// JWT or the newer "publishable" key works here - supabase_flutter
  /// accepts both under this same parameter.
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static const String eventImagesBucket = 'event-images';
}
