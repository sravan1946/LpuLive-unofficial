import 'package:flutter/material.dart';
import '../services/theme_controller.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.instance.themeModeListenable,
        builder: (context, mode, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Appearance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text('Theme', style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              _ThemeOption(
                label: 'System',
                icon: Icons.app_settings_alt_rounded,
                selected: mode == ThemeMode.system,
                onTap: () => ThemeController.instance.setThemeMode(ThemeMode.system),
              ),
              _ThemeOption(
                label: 'Light',
                icon: Icons.wb_sunny_outlined,
                selected: mode == ThemeMode.light,
                onTap: () => ThemeController.instance.setThemeMode(ThemeMode.light),
              ),
              _ThemeOption(
                label: 'Dark',
                icon: Icons.nights_stay_outlined,
                selected: mode == ThemeMode.dark,
                onTap: () => ThemeController.instance.setThemeMode(ThemeMode.dark),
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

  const _ThemeOption({required this.label, required this.icon, required this.selected, required this.onTap});

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



