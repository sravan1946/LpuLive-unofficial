// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Project imports:
import '../services/foreground_service_manager.dart';

/// Shows a dialog to request foreground service permission
class ForegroundServicePermissionDialog extends StatelessWidget {
  final VoidCallback? onPermissionGranted;
  final VoidCallback? onPermissionDenied;

  const ForegroundServicePermissionDialog({
    super.key,
    this.onPermissionGranted,
    this.onPermissionDenied,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Background Connection Permission'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'To maintain your WebSocket connection when your phone is locked, LPU Live needs permission to run in the background.',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 16),
          Text(
            'This will:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('• Keep your connection active when phone is locked'),
          Text('• Show a persistent notification'),
          Text('• Allow real-time message delivery'),
          SizedBox(height: 16),
          Text(
            'You can disable this permission later in Settings if needed.',
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
      debugPrint('🔧 [PermissionDialog] Requesting foreground service permission...');

      // Request permission
      await ForegroundServiceManager.requestPermission();

      // Check if permission was granted
      final hasPermission = await ForegroundServiceManager.checkPermission();

      if (hasPermission) {
        debugPrint('✅ [PermissionDialog] Permission granted');
        onPermissionGranted?.call();

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Background connection enabled!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        debugPrint('❌ [PermissionDialog] Permission denied');
        onPermissionDenied?.call();

        // Show info message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission denied. Connection may drop when phone is locked.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ [PermissionDialog] Error requesting permission: $e');
      onPermissionDenied?.call();
    }
  }
}

/// Utility class to show permission dialog
class ForegroundServicePermissionHelper {
  /// Show permission dialog if needed
  static Future<bool> showPermissionDialogIfNeeded(BuildContext context) async {
    try {
      // Check if we already have permission
      final hasPermission = await ForegroundServiceManager.checkPermission();

      if (hasPermission) {
        debugPrint('✅ [PermissionHelper] Permission already granted');
        return true;
      }

      // Show permission dialog
      final granted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => ForegroundServicePermissionDialog(
          onPermissionGranted: () {
            Navigator.of(context).pop(true);
          },
          onPermissionDenied: () {
            Navigator.of(context).pop(false);
          },
        ),
      );

      return granted ?? false;
    } catch (e) {
      debugPrint('❌ [PermissionHelper] Error checking permission: $e');
      return false;
    }
  }

  /// Check if permission is granted
  static Future<bool> isPermissionGranted() async {
    try {
      return await ForegroundServiceManager.checkPermission();
    } catch (e) {
      debugPrint('❌ [PermissionHelper] Error checking permission: $e');
      return false;
    }
  }
}
