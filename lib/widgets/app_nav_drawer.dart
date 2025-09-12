import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/user_models.dart';
import '../widgets/network_image.dart';
import '../services/chat_services.dart';
import '../pages/token_input_page.dart';
import '../pages/profile_page.dart';
import '../pages/theme_settings_page.dart';
import '../pages/notifications_page.dart';

class AppNavDrawer extends StatelessWidget {
  const AppNavDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = currentUser;

    return Drawer(
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: SafeArea(
            top: true,
            bottom: false,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.75),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (user != null)
              InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: SafeNetworkImage(
                          imageUrl: user.userImageUrl ?? '',
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          highQuality: true,
                          errorWidget: CircleAvatar(
                            radius: 28,
                            backgroundColor: scheme.primary,
                            child: Text(
                              (user.displayName.isNotEmpty
                                      ? user.displayName
                                      : user.name)
                                  .characters
                                  .first
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName.isNotEmpty
                                  ? user.displayName
                                  : user.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.id,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: scheme.onSurface.withOpacity(0.6),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.color_lens_outlined),
                    title: const Text('Theme'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ThemeSettingsPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Notifications'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NotificationsPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout'),
              textColor: Colors.redAccent,
              iconColor: Colors.redAccent,
              onTap: () async {
                final navigator = Navigator.of(context);
                Navigator.of(context).pop();
                await TokenStorage.clearToken();
                currentUser = null;
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const TokenInputApp()),
                  (route) => false,
                );
              },
            ),
          ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


