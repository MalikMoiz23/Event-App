import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/session_provider.dart';
import '../theme/app_dimens.dart';
import '../theme/hit_logo.dart';
import 'admin/admin_home_screen.dart';
import 'auth/login_screen.dart';
import 'user/user_shell.dart';

/// Root router: a splash while the session bootstraps, the sign-in flow when
/// signed out, and the admin or attendee shell by role.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, session, _) {
        if (session.loading) return const _Splash();

        final profile = session.profile;
        if (profile == null) {
          return LoginScreen(
            errorMessage: session.authError,
            onErrorShown: session.clearAuthError,
          );
        }

        // Keyed by id so switching accounts rebuilds the shell from scratch
        // rather than reusing the previous user's tab state and streams.
        return profile.isAdmin
            ? AdminHomeScreen(key: ValueKey(profile.id), profile: profile)
            : UserShell(key: ValueKey(profile.id), profile: profile);
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HitLogo(size: 88),
            Gap.h24,
            SizedBox(
              width: 96,
              child: ClipRRect(
                borderRadius: Corner.pillAll,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: scheme.surfaceContainerHigh,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
