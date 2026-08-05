import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../services/favorite_service.dart';
import '../services/rsvp_service.dart';
import '../services/session_provider.dart';
import '../theme/hit_logo.dart';
import 'admin/admin_home_screen.dart';
import 'auth/login_screen.dart';
import 'user/user_home_screen.dart';

/// Root router: shows a splash while the session bootstraps, the login flow
/// when signed out, and routes to the admin or user home screen by role.
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.authService,
    required this.eventService,
    required this.rsvpService,
    required this.favoriteService,
  });

  final AuthService authService;
  final EventService eventService;
  final RsvpService rsvpService;
  final FavoriteService favoriteService;

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, session, _) {
        if (session.loading) {
          return const Scaffold(
            body: Center(child: HitLogo(size: 96)),
          );
        }
        final profile = session.profile;
        if (profile == null) {
          return LoginScreen(
            authService: authService,
            errorMessage: session.authError,
            onErrorShown: session.clearAuthError,
          );
        }
        if (profile.isAdmin) {
          return AdminHomeScreen(
            profile: profile,
            eventService: eventService,
            authService: authService,
            rsvpService: rsvpService,
          );
        }
        return UserHomeScreen(
          profile: profile,
          eventService: eventService,
          authService: authService,
          rsvpService: rsvpService,
          favoriteService: favoriteService,
        );
      },
    );
  }
}
