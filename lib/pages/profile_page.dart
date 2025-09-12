import 'package:flutter/material.dart';
import '../models/user_models.dart';
import '../widgets/network_image.dart';
import 'token_input_page.dart';
import '../services/chat_services.dart';
// drawer not used on profile; using back button

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'Are you sure you want to logout? This will require you to enter your token again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop();
              await TokenStorage.clearToken();
              currentUser = null;
              navigator.pushReplacement(
                MaterialPageRoute(builder: (context) => const TokenInputApp()),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14)),
          const Divider(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = currentUser;

    return Scaffold(
      // No drawer here; show a back button instead of hamburger
      appBar: AppBar(
        title: const Text('Profile'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: user == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No user data available.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _logout(context),
                    child: const Text('Logout'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: theme.colorScheme.primary,
                          child: ClipOval(
                            child: SafeNetworkImage(
                              imageUrl: user.userImageUrl ?? '',
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              highQuality: true,
                              errorWidget: Center(
                                child: Text(
                                  user.displayName.isNotEmpty
                                      ? user.displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          user.displayName.isNotEmpty
                              ? user.displayName
                              : user.name,
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Name', user.name),
                          _buildInfoRow('Display Name', user.displayName),
                          _buildInfoRow('Registration Number', user.id),
                          _buildInfoRow('Department', user.department),
                          _buildInfoRow('Category', user.category),
                          _buildInfoRow(
                            'Groups',
                            '${user.groups.length} groups',
                          ),
                          _buildInfoRow(
                            'Can Create Groups',
                            user.createGroups ? 'Yes' : 'No',
                          ),
                          _buildInfoRow(
                            'One-to-One Chat',
                            user.oneToOne ? 'Enabled' : 'Disabled',
                          ),
                          _buildInfoRow(
                            'Chat Suspended',
                            user.isChatSuspended ? 'Yes' : 'No',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
