// Flutter imports:
import 'package:flutter/material.dart';

// Project imports:
import '../services/theme_service.dart';

// Global theme service instance
final ThemeService globalThemeService = ThemeService();

class ThemeProvider extends InheritedWidget {
  final ThemeService themeService;

  const ThemeProvider({
    super.key,
    required this.themeService,
    required super.child,
  });

  static ThemeService of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<ThemeProvider>();
    return provider?.themeService ?? globalThemeService;
  }

  @override
  bool updateShouldNotify(ThemeProvider oldWidget) {
    return themeService != oldWidget.themeService;
  }
}
