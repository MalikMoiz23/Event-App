import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the light/dark/system theme choice across restarts.
///
/// "System" is a real, selectable option rather than just the initial value:
/// a user who has set their phone to switch at sunset expects the app to
/// follow, and a two-way toggle throws that preference away the first time it
/// is touched.
class ThemeController extends ChangeNotifier {
  ThemeController() {
    _load();
  }

  static const _prefsKey = 'theme_mode';

  ThemeMode mode = ThemeMode.system;
  bool loaded = false;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    mode = _decode(prefs.getString(_prefsKey));
    loaded = true;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode next) async {
    if (next == mode) return;
    mode = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _encode(next));
  }

  /// Flips between light and dark for the icon button in an app bar. From
  /// "system" it moves to whichever is the opposite of what is on screen, so
  /// the tap always visibly does something.
  Future<void> toggle({Brightness? current}) {
    final effective = switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => current ?? Brightness.light,
    };
    return setMode(
      effective == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  String get label => switch (mode) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'Match system',
  };

  static ThemeMode _decode(String? stored) => switch (stored) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String _encode(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}
