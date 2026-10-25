// lib/theme/theme-controller.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static const String _preferenceKey = 'chatmate.theme_mode';

  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;

  /// Restores the last chosen mode. A first launch has no saved value, so it
  /// stays on the light default.
  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_preferenceKey);
    final restored = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    if (_mode == restored) return;
    _mode = restored;
    notifyListeners();
  }

  Future<void> toggle() async {
    await set(_mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> set(ThemeMode mode) async {
    if (_mode != mode) {
      _mode = mode;
      notifyListeners();
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, mode.name);
  }
}

// Global instance — simple, no provider/riverpod needed
final themeController = ThemeController();
