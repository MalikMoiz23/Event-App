import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/event_index.dart';
import 'screens/auth_gate.dart';
import 'services/auth_service.dart';
import 'services/event_service.dart';
import 'services/favorite_service.dart';
import 'services/session_provider.dart';
import 'services/theme_controller.dart';
import 'services/ticket_service.dart';
import 'theme/app_theme.dart';

class HitEventsApp extends StatelessWidget {
  const HitEventsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final authService = AuthService(client);

    return MultiProvider(
      providers: [
        // Services are provided rather than threaded through constructors.
        // Passing four of them down through the gate into every screen meant
        // a screen five levels deep declared parameters purely to hand them
        // on, and adding a fifth service touched every file in between.
        Provider<AuthService>.value(value: authService),
        Provider<EventService>(create: (_) => EventService(client)),
        Provider<TicketService>(create: (_) => TicketService(client)),
        Provider<FavoriteService>(create: (_) => FavoriteService(client)),
        ChangeNotifierProvider(create: (_) => SessionProvider(authService)),
        ChangeNotifierProvider(create: (_) => ThemeController()),

        // Seat counts are read by nearly every attendee screen, so the
        // subscription lives here once instead of one per screen. An empty
        // index is a valid starting state - a card shows no seat line until
        // the first snapshot lands, rather than blocking on it.
        StreamProvider<EventStatsIndex>(
          initialData: EventStatsIndex.empty,
          create: (ctx) =>
              ctx.read<EventService>().watchStats().map(EventStatsIndex.new),
        ),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) {
          return MaterialApp(
            title: 'HIT EVO',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeController.mode,
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}
