// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:permission_handler/permission_handler.dart';

/// Helper service for managing notification permissions
class NotificationPermissionHelper {
  /// Check if notification permission is granted
  static Future<bool> checkPermission() async {
    try {
      final status = await Permission.notification.status;
      debugPrint('🔔 [NotificationPermission] Current status: $status');
      return status.isGranted;
    } catch (e) {
      debugPrint('❌ [NotificationPermission] Error checking permission: $e');
      return false;
    }
  }

  /// Request notification permission
  static Future<bool> requestPermission() async {
    try {
      debugPrint('🔔 [NotificationPermission] Requesting permission...');
      final status = await Permission.notification.request();
      debugPrint('🔔 [NotificationPermission] Permission result: $status');
      return status.isGranted;
    } catch (e) {
      debugPrint('❌ [NotificationPermission] Error requesting permission: $e');
      return false;
    }
  }

  /// Check if we should show rationale (permission was denied before but not permanently)
  static Future<bool> shouldShowRationale() async {
    try {
      final status = await Permission.notification.status;
      // Show rationale if permission is denied but not permanently
      return status.isDenied;
    } catch (e) {
      debugPrint('❌ [NotificationPermission] Error checking rationale: $e');
      return false;
    }
  }

  /// Check if permission is permanently denied
  static Future<bool> isPermanentlyDenied() async {
    try {
      final status = await Permission.notification.status;
      return status.isPermanentlyDenied;
    } catch (e) {
      debugPrint('❌ [NotificationPermission] Error checking permanent denial: $e');
      return false;
    }
  }

  /// Open app settings (useful when permission is permanently denied)
  static Future<bool> openSettings() async {
    try {
      debugPrint('⚙️ [NotificationPermission] Opening app settings...');
      return await openAppSettings();
    } catch (e) {
      debugPrint('❌ [NotificationPermission] Error opening settings: $e');
      return false;
    }
  }
}
