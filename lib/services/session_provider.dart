import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';

/// Holds the signed-in user's profile (and therefore role) for the whole
/// widget tree, refreshing whenever Supabase auth state changes.
class SessionProvider extends ChangeNotifier {
  SessionProvider(this._auth) {
    _sub = _auth.onAuthStateChange.listen(_onAuthChange);
    _bootstrap();
  }

  final AuthService _auth;
  late final StreamSubscription<AuthState> _sub;

  UserProfile? profile;
  bool loading = true;

  /// Set when a signed-in user's profile row could not be loaded (e.g. the
  /// `profiles` row is missing). Cleared once shown by the UI via
  /// [clearAuthError]. A failed profile load signs the user back out, since
  /// the app cannot determine their role without it.
  String? authError;

  bool get isSignedIn => profile != null;
  bool get isAdmin => profile?.isAdmin ?? false;

  Future<void> _bootstrap() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _loadProfile(user.id);
    }
    loading = false;
    notifyListeners();
  }

  Future<void> _onAuthChange(AuthState state) async {
    final user = state.session?.user;
    if (user == null) {
      profile = null;
    } else {
      await _loadProfile(user.id);
    }
    loading = false;
    notifyListeners();
  }

  Future<void> _loadProfile(String userId) async {
    try {
      profile = await _auth.fetchProfile(userId);
    } catch (e) {
      profile = null;
      authError =
          'Could not load your account (profile row missing or blocked by a '
          'database policy). Signed out. Details: $e';
      await _auth.signOut();
    }
  }

  void clearAuthError() {
    authError = null;
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
