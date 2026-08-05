import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's light/dark theme choice across app restarts.
class ThemeController extends ChangeNotifier {
  ThemeController() {
    _load();
  }

  static const _prefsKey = 'theme_mode';

  ThemeMode mode = ThemeMode.system;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    mode = switch (prefs.getString(_prefsKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> toggle() async {
    mode = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode == ThemeMode.dark ? 'dark' : 'light');
  }
}
