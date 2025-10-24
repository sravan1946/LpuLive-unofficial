// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Manages Android foreground service to keep WebSocket connections alive
class ForegroundServiceManager {
  static const MethodChannel _channel = MethodChannel('com.lpulive.foreground_service');

  static bool _isServiceRunning = false;

  /// Start foreground service to maintain WebSocket connection
  static Future<bool> startService(String chatToken) async {
    try {
      debugPrint('🔧 [ForegroundService] Starting foreground service...');

      // First check if we have permission
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        debugPrint('❌ [ForegroundService] Permission not granted, requesting...');
        await requestPermission();
        return false;
      }

      final result = await _channel.invokeMethod('startForegroundService', {
        'chatToken': chatToken,
      });

      _isServiceRunning = result == true;

      if (_isServiceRunning) {
        debugPrint('✅ [ForegroundService] Foreground service started successfully');
      } else {
        debugPrint('❌ [ForegroundService] Failed to start foreground service');
      }

      return _isServiceRunning;
    } catch (e) {
      debugPrint('❌ [ForegroundService] Error starting service: $e');
      return false;
    }
  }

  /// Check if we have foreground service permission
  static Future<bool> checkPermission() async {
    try {
      final result = await _channel.invokeMethod('checkForegroundServicePermission');
      return result == true;
    } catch (e) {
      debugPrint('❌ [ForegroundService] Error checking permission: $e');
      return false;
    }
  }

  /// Request foreground service permission
  static Future<bool> requestPermission() async {
    try {
      debugPrint('🔧 [ForegroundService] Requesting permission...');
      final result = await _channel.invokeMethod('requestForegroundServicePermission');
      return result == true;
    } catch (e) {
      debugPrint('❌ [ForegroundService] Error requesting permission: $e');
      return false;
    }
  }

  /// Stop foreground service
  static Future<bool> stopService() async {
    try {
      debugPrint('🔧 [ForegroundService] Stopping foreground service...');

      final result = await _channel.invokeMethod('stopForegroundService');

      _isServiceRunning = result != true;

      if (!_isServiceRunning) {
        debugPrint('✅ [ForegroundService] Foreground service stopped successfully');
      } else {
        debugPrint('❌ [ForegroundService] Failed to stop foreground service');
      }

      return !_isServiceRunning;
    } catch (e) {
      debugPrint('❌ [ForegroundService] Error stopping service: $e');
      return false;
    }
  }

  /// Check if service is running
  static bool get isServiceRunning => _isServiceRunning;

  /// Request battery optimization exemption (Android only)
  static Future<bool> requestBatteryOptimizationExemption() async {
    try {
      debugPrint('🔋 [ForegroundService] Requesting battery optimization exemption...');

      // This would typically open the battery optimization settings
      // For now, we'll just log that we're requesting it
      debugPrint('📱 [ForegroundService] Please disable battery optimization for LPU Live in Settings > Battery > Battery Optimization');

      return true;
    } catch (e) {
      debugPrint('❌ [ForegroundService] Error requesting battery exemption: $e');
      return false;
    }
  }
}
