// Dart imports:
import 'dart:ui';

// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Package imports:
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// Project imports:
import '../models/current_user_state.dart';
import '../models/user_models.dart';
import '../pages/bug_report_page.dart';
import '../pages/feature_request_page.dart';
import '../pages/login_page.dart';
import '../pages/profile_page.dart';
import '../pages/theme_settings_page.dart';
import '../services/chat_services.dart';
import '../widgets/network_image.dart';

class AppNavDrawer extends StatefulWidget {
  const AppNavDrawer({super.key});

  @override
  State<AppNavDrawer> createState() => _AppNavDrawerState();
}

class _AppNavDrawerState extends State<AppNavDrawer> {
  String _appVersion = '';
  String _buildNumber = '';

  static const _githubBugIssuesUrl =
      'https://github.com/sravan1946/LpuLive-unofficial/issues/new/choose';
  static const _githubFeatureIssuesUrl =
      'https://github.com/sravan1946/LpuLive-unofficial/issues/new?template=feature_request.md';

  @override
  void initState() {
    super.initState();
    _getAppVersion();
  }

  Future<void> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
      });
    } catch (e) {
      setState(() {
        _appVersion = 'Unknown'; // fallback version
        _buildNumber = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = currentUser;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.70,
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
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.75),
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
                          MaterialPageRoute(
                            builder: (_) => const ProfilePage(),
                          ),
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
                                      color: scheme.onSurface.withValues(
                                        alpha: 0.6,
                                      ),
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
                              MaterialPageRoute(
                                builder: (_) => const ThemeSettingsPage(),
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.bug_report_outlined),
                          title: const Text('Report a Bug'),
                          onTap: () => _handleFeedbackTap(
                            pageBuilder: (_) => const BugReportPage(),
                            dialogTitle: 'Try GitHub Issues First?',
                            dialogMessage:
                                'GitHub issues make it easier to chat, attach screenshots, and track progress. Would you like to open an issue instead?',
                            issuesUrl: _githubBugIssuesUrl,
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.lightbulb_outline),
                          title: const Text('Request a Feature'),
                          onTap: () => _handleFeedbackTap(
                            pageBuilder: (_) => const FeatureRequestPage(),
                            dialogTitle: 'Share on GitHub?',
                            dialogMessage:
                                'Feature requests get more visibility on GitHub where others can upvote and discuss. Want to open an issue instead?',
                            issuesUrl: _githubFeatureIssuesUrl,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Version text
                  if (_appVersion.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Center(
                        child: Text(
                          'Version: ${kDebugMode && _buildNumber.isNotEmpty ? 'v$_appVersion+$_buildNumber' : _appVersion}',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
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
                      setCurrentUser(null);
                      navigator.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginApp()),
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

  Future<void> _handleFeedbackTap({
    required WidgetBuilder pageBuilder,
    required String dialogTitle,
    required String dialogMessage,
    required String issuesUrl,
  }) async {
    if (!mounted) return;

    final navigator = Navigator.of(context);
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(dialogTitle),
          content: Text(dialogMessage),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
                _openIssuesLink(issuesUrl, scaffoldMessenger);
              },
              child: const Text('GitHub Issues'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (proceed != true) {
      return;
    }

    navigator.pop(); // close the drawer
    await Future<void>.delayed(const Duration(milliseconds: 180));

    await rootNavigator.push(MaterialPageRoute(builder: pageBuilder));
  }

  Future<void> _openIssuesLink(
    String url,
    ScaffoldMessengerState scaffoldMessenger,
  ) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Unable to open GitHub issues in your browser.'),
        ),
      );
    }
  }
}
