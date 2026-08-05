import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_gate.dart';
import 'services/auth_service.dart';
import 'services/event_service.dart';
import 'services/favorite_service.dart';
import 'services/rsvp_service.dart';
import 'services/session_provider.dart';
import 'services/theme_controller.dart';
import 'theme/app_theme.dart';

class HitEventsApp extends StatelessWidget {
  const HitEventsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final authService = AuthService(client);
    final eventService = EventService(client);
    final rsvpService = RsvpService(client);
    final favoriteService = FavoriteService(client);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionProvider(authService)),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) {
          return MaterialApp(
            title: 'HIT EVO',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeController.mode,
            home: AuthGate(
              authService: authService,
              eventService: eventService,
              rsvpService: rsvpService,
              favoriteService: favoriteService,
            ),
          );
        },
      ),
    );
  }
}
