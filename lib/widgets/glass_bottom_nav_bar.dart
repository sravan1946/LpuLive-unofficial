// Dart imports:
import 'dart:ui';

// Flutter imports:
import 'package:flutter/material.dart';

class GlassBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const GlassBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const int itemCount = 3;
                    final double itemWidth = constraints.maxWidth / itemCount;
                    return Stack(
                      children: [
                        // Sliding selection indicator (orange glass highlight)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          left: selectedIndex * itemWidth,
                          top: 6,
                          width: itemWidth,
                          height: 52,
                          child: _GlassIndicator(),
                        ),
                        // Foreground nav items
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _NavItem(
                              icon: Icons.school_outlined,
                              selectedIcon: Icons.school,
                              label: 'University',
                              isSelected: selectedIndex == 0,
                              onTap: () => onItemSelected(0),
                            ),
                            _NavItem(
                              icon: Icons.group_outlined,
                              selectedIcon: Icons.group,
                              label: 'Personal',
                              isSelected: selectedIndex == 1,
                              onTap: () => onItemSelected(1),
                            ),
                            _NavItem(
                              icon: Icons.forum_outlined,
                              selectedIcon: Icons.forum,
                              label: 'DMs',
                              isSelected: selectedIndex == 2,
                              onTap: () => onItemSelected(2),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // Use a subtle orange-tinted glass with a glow on top
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.primary.withValues(alpha: 0.12),
            colorScheme.primary.withValues(alpha: 0.05),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.18),
            blurRadius: 18,
            spreadRadius: 0.5,
            offset: const Offset(0, -4), // subtle glow upward (top shadow)
          ),
        ],
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Color foregroundColor = isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation),
                  child: child,
                ),
                child: Icon(
                  isSelected ? selectedIcon : icon,
                  key: ValueKey<bool>(isSelected),
                  color: foregroundColor,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style:
                    theme.textTheme.labelSmall?.copyWith(
                      color: foregroundColor,
                      height: 1,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ) ??
                    TextStyle(color: foregroundColor, height: 1),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
