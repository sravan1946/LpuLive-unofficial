// Flutter imports:
import 'package:flutter/material.dart';

/// Utility class for layout calculations
class LayoutUtils {
  // Bottom navigation bar dimensions (matching glass_bottom_nav_bar.dart)
  static const double bottomNavBarHeight = 64.0;
  static const double bottomNavBarBottomPadding = 12.0;

  /// Calculates the bottom padding needed to account for the bottom navigation bar
  /// This ensures list items can scroll above the nav bar on all screen sizes
  static double getBottomNavBarPadding(BuildContext context, {double extraSpacing = 16.0}) {
    final mediaQuery = MediaQuery.of(context);
    final safeAreaBottom = mediaQuery.padding.bottom;

    // Total height = nav bar content + bottom padding + safe area + extra spacing
    return bottomNavBarHeight + bottomNavBarBottomPadding + safeAreaBottom + extraSpacing;
  }
}
