// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeService() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_themeKey) ?? 0;
      _themeMode = ThemeMode.values[themeIndex];
      notifyListeners();
    } catch (e) {
      print('Error loading theme: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      _themeMode = mode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, mode.index);
      notifyListeners();
    } catch (e) {
      print('Error saving theme: $e');
    }
  }

  String getThemeDisplayName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  IconData getThemeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }
}
