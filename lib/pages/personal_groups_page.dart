import 'package:flutter/material.dart';
import '../widgets/app_toast.dart';
// user info not needed in this app bar anymore
// Drawer is provided by parent Scaffold; do not declare here

class PersonalGroupsPage extends StatelessWidget {
  final dynamic wsService; // Placeholder for future use
  final VoidCallback? onOpenDrawer;

  const PersonalGroupsPage({super.key, required this.wsService, this.onOpenDrawer});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            debugPrint('🫓 PersonalGroupsPage hamburger tapped');
            onOpenDrawer?.call();
          },
          tooltip: 'Menu',
        ),
        title: const Text('Personal Groups'),
        actions: const [],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_add, size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Personal Groups',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Create and manage your own groups',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Text(
              'Coming Soon!',
              style: TextStyle(
                color: scheme.primary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showCreateGroupSheet(context);
        },
        tooltip: 'Create New Group',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateGroupSheet(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create new group',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  hintText: 'e.g., Project Phoenix',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    showAppToast(
                      context,
                      'Please enter a group name',
                      type: ToastType.warning,
                    );
                    return;
                  }
                  Navigator.pop(context);
                  showAppToast(
                    context,
                    'Group "$name" will be created soon',
                    type: ToastType.info,
                  );
                },
                icon: const Icon(Icons.check),
                label: const Text('Create'),
              ),
            ],
          ),
        );
      },
    );
  }
}
