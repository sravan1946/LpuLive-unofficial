import 'package:flutter/material.dart';

// LPU brand-inspired palette
const Color _lpuOrange = Color(0xFFF58220); // primary orange
const Color _lpuOrangeDark = Color(0xFFCC6D15);
const Color _lpuCharcoal = Color(0xFF121212); // near-black for dark backgrounds
const Color _lpuGrey = Color(0xFF1E1E1E);

final ColorScheme lpuLightColorScheme =
    ColorScheme.fromSeed(
      seedColor: _lpuOrange,
      brightness: Brightness.light,
    ).copyWith(
      primary: _lpuOrange,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFFFE9D6),
      onPrimaryContainer: _lpuOrangeDark,
      secondary: const Color(0xFF3C3C3C),
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: const Color(0xFF1B1B1B),
      surfaceContainerHighest: const Color(0xFFF5F5F5),
      onSurfaceVariant: const Color(0xFF5A5A5A),
      outline: const Color(0xFFE5E5E5),
    );

final ThemeData lpuTheme = ThemeData(
  useMaterial3: true,
  colorScheme: lpuLightColorScheme,
  scaffoldBackgroundColor: lpuLightColorScheme.surface,
  appBarTheme: AppBarTheme(
    backgroundColor: lpuLightColorScheme.surface,
    foregroundColor: lpuLightColorScheme.onSurface,
    elevation: 0,
    centerTitle: true,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: lpuLightColorScheme.surfaceContainerHighest,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: lpuLightColorScheme.outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: lpuLightColorScheme.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: lpuLightColorScheme.primary, width: 1.6),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _lpuOrange,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: _lpuOrange,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  cardTheme: CardThemeData(
    color: lpuLightColorScheme.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: EdgeInsets.zero,
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: lpuLightColorScheme.surface,
    selectedItemColor: _lpuOrange,
    unselectedItemColor: lpuLightColorScheme.onSurfaceVariant,
    showUnselectedLabels: true,
    elevation: 10,
    type: BottomNavigationBarType.fixed,
  ),
);

final ColorScheme lpuDarkColorScheme =
    ColorScheme.fromSeed(
      seedColor: _lpuOrange,
      brightness: Brightness.dark,
    ).copyWith(
      primary: _lpuOrange,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF2A1A10),
      onPrimaryContainer: _lpuOrange,
      secondary: Colors.white70,
      surface: _lpuCharcoal,
      onSurface: Colors.white,
      surfaceContainerHighest: _lpuGrey,
      onSurfaceVariant: Colors.white70,
      outline: const Color(0xFF333333),
    );

final ThemeData lpuDarkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: lpuDarkColorScheme,
  scaffoldBackgroundColor: lpuDarkColorScheme.surface,
  appBarTheme: AppBarTheme(
    backgroundColor: lpuDarkColorScheme.surface,
    foregroundColor: lpuDarkColorScheme.onSurface,
    elevation: 0,
    centerTitle: true,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: lpuDarkColorScheme.surfaceContainerHighest,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: lpuDarkColorScheme.outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: lpuDarkColorScheme.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: lpuDarkColorScheme.primary, width: 1.6),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _lpuOrange,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      side: BorderSide(color: lpuDarkColorScheme.outline),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: _lpuOrange,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  cardTheme: CardThemeData(
    color: lpuDarkColorScheme.surfaceContainerHighest,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: EdgeInsets.zero,
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: lpuDarkColorScheme.surface,
    selectedItemColor: _lpuOrange,
    unselectedItemColor: lpuDarkColorScheme.onSurfaceVariant,
    showUnselectedLabels: true,
    elevation: 10,
    type: BottomNavigationBarType.fixed,
  ),
);
