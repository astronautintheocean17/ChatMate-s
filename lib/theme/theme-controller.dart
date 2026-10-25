// lib/theme/theme-controller.dart
import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;

  void toggle() {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void set(ThemeMode m) {
    _mode = m;
    notifyListeners();
  }
}

// Global instance — simple, no provider/riverpod needed
final themeController = ThemeController();