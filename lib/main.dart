import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.publishableKey.isEmpty) {
    throw StateError(
      'SUPABASE_PUBLISHABLE_KEY is not set. Run with:\n'
      'flutter run --dart-define=SUPABASE_PUBLISHABLE_KEY=your_key_here',
    );
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  runApp(const HitEventsApp());
}
