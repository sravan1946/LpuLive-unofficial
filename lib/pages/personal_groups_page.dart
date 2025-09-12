import 'package:flutter/material.dart';
import '../widgets/app_toast.dart';
import '../models/user_models.dart';
import 'profile_page.dart';

class PersonalGroupsPage extends StatelessWidget {
  final dynamic wsService; // Placeholder for future use

  const PersonalGroupsPage({super.key, required this.wsService});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Personal Groups'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                child: (currentUser?.userImageUrl != null &&
                        currentUser!.userImageUrl!.isNotEmpty)
                    ? ClipOval(
                        child: Image.network(
                          currentUser!.userImageUrl!,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.person, size: 18);
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Icon(Icons.person, size: 18);
                          },
                        ),
                      )
                    : const Icon(Icons.person, size: 18),
              ),
            ),
          ),
        ],
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
