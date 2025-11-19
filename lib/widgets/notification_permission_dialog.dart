// Flutter imports:
import 'package:flutter/material.dart';

// Project imports:
import '../services/notification_permission_helper.dart';

/// Shows a dialog to explain why notification permission is needed
class NotificationPermissionDialog extends StatelessWidget {
  final VoidCallback? onPermissionGranted;
  final VoidCallback? onPermissionDenied;

  const NotificationPermissionDialog({
    super.key,
    this.onPermissionGranted,
    this.onPermissionDenied,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Stay Updated with Notifications'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LPU Live needs notification access to keep you connected with your messages and updates.',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 16),
          Text(
            'This will allow you to:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('• Receive real-time message notifications'),
          Text('• Get instant updates from your groups'),
          Text('• Stay connected even when app is closed'),
          SizedBox(height: 16),
          Text(
            'You can change this permission anytime in Settings.',
            style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onPermissionDenied?.call();
          },
          child: const Text('Not Now'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.of(context).pop();
            await _requestPermission(context);
          },
          child: const Text('Allow'),
        ),
      ],
    );
  }

  Future<void> _requestPermission(BuildContext context) async {
    try {
      debugPrint('🔔 [NotificationDialog] Requesting notification permission...');

      // Request permission
      final granted = await NotificationPermissionHelper.requestPermission();

      if (granted) {
        debugPrint('✅ [NotificationDialog] Permission granted');
        onPermissionGranted?.call();

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notifications enabled!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        debugPrint('❌ [NotificationDialog] Permission denied');
        onPermissionDenied?.call();

        // Show info message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notifications disabled. You can enable them later in Settings.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ [NotificationDialog] Error requesting permission: $e');
      onPermissionDenied?.call();
    }
  }
}

/// Utility class to show notification permission dialog
class NotificationPermissionDialogHelper {
  /// Show permission dialog if needed
  static Future<bool> showPermissionDialogIfNeeded(BuildContext context) async {
    try {
      // Check if we already have permission
      final hasPermission = await NotificationPermissionHelper.checkPermission();

      if (hasPermission) {
        debugPrint('✅ [NotificationDialogHelper] Permission already granted');
        return true;
      }

      // Check if we should show the dialog (not permanently denied)
      final shouldShow = await NotificationPermissionHelper.shouldShowRationale();

      if (!shouldShow) {
        debugPrint('⚠️ [NotificationDialogHelper] Permission permanently denied or first time');
        // For first time, we should show the dialog
        // For permanently denied, we skip (user must go to settings)
      }

      // Show permission dialog
      if (!context.mounted) return false;

      final granted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => NotificationPermissionDialog(
          onPermissionGranted: () {},
          onPermissionDenied: () {},
        ),
      );

      return granted ?? false;
    } catch (e) {
      debugPrint('❌ [NotificationDialogHelper] Error checking permission: $e');
      return false;
    }
  }

  /// Check if permission is granted
  static Future<bool> isPermissionGranted() async {
    try {
      return await NotificationPermissionHelper.checkPermission();
    } catch (e) {
      debugPrint('❌ [NotificationDialogHelper] Error checking permission: $e');
      return false;
    }
  }
}
