// Flutter imports:
import 'package:flutter/material.dart';

// Project imports:
import '../providers/theme_provider.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final themeService = ThemeProvider.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: AnimatedBuilder(
        animation: themeService,
        builder: (context, _) {
          final mode = themeService.themeMode;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Appearance',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text('Theme', style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              _ThemeOption(
                label: 'System',
                icon: Icons.app_settings_alt_rounded,
                selected: mode == ThemeMode.system,
                onTap: () => themeService.setThemeMode(ThemeMode.system),
              ),
              _ThemeOption(
                label: 'Light',
                icon: Icons.wb_sunny_outlined,
                selected: mode == ThemeMode.light,
                onTap: () => themeService.setThemeMode(ThemeMode.light),
              ),
              _ThemeOption(
                label: 'Dark',
                icon: Icons.nights_stay_outlined,
                selected: mode == ThemeMode.dark,
                onTap: () => themeService.setThemeMode(ThemeMode.dark),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}
