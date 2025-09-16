// Flutter imports:
import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Enable notifications'),
            subtitle: const Text('Turn on app notifications (placeholder)'),
            value: true,
            onChanged: (_) {},
          ),
          const SizedBox(height: 8),
          Text(
            'Fine-grained notification settings coming soon.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
