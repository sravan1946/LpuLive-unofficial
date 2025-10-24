// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:connectivity_plus/connectivity_plus.dart';

// Project imports:
import 'foreground_service_manager.dart';

/// Background service for keeping the app process alive when backgrounded/locked.
/// Does NOT open its own WebSocket; the main WebSocketChatService remains the single source of truth.
class BackgroundWebSocketService {
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  static String? _lastChatToken;

  /// Initialize the background service (foreground service + connectivity monitoring)
  static Future<void> initialize() async {
    debugPrint('🔧 [BackgroundWebSocket] Initializing...');
    _startConnectivityMonitoring();
    await ForegroundServiceManager.requestBatteryOptimizationExemption();
  }

  /// Start connectivity monitoring
  static void _startConnectivityMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      debugPrint('📡 [BackgroundWebSocket] Connectivity changed: $result');
      // Note: We do not manage WebSocket reconnection here.
      // The main WebSocketChatService handles its own reconnection.
    });
  }

  /// Start the background service (foreground service) to keep the process alive
  static Future<void> startBackgroundService(String chatToken) async {
    _lastChatToken = chatToken;
    await ForegroundServiceManager.startService(chatToken);
  }

  /// Stop the background service
  static Future<void> stopBackgroundService() async {
    await ForegroundServiceManager.stopService();
  }

  /// Dispose
  static Future<void> dispose() async {
    _connectivitySubscription?.cancel();
    await ForegroundServiceManager.stopService();
  }
}
