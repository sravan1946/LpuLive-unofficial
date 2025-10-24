// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'background_websocket_service.dart';

/// Manages app lifecycle transitions and WebSocket connection persistence
class AppLifecycleManager {
  static AppLifecycleManager? _instance;
  static AppLifecycleManager get instance => _instance ??= AppLifecycleManager._();

  AppLifecycleManager._();

  bool _isInitialized = false;
  AppLifecycleState _currentState = AppLifecycleState.resumed;
  Timer? _backgroundTimer;
  Timer? _foregroundTimer;

  // Background handling
  static const Duration _backgroundTimeout = Duration(minutes: 5);
  static const Duration _foregroundReconnectDelay = Duration(seconds: 2);

  /// Initialize the lifecycle manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('🔄 [AppLifecycle] Initializing lifecycle manager...');

    // Set up system message channel for lifecycle events
    const platform = MethodChannel('com.lpulive.lifecycle');

    try {
      platform.setMethodCallHandler(_handleMethodCall);
      debugPrint('✅ [AppLifecycle] Lifecycle manager initialized');
    } catch (e) {
      debugPrint('❌ [AppLifecycle] Failed to initialize: $e');
    }

    _isInitialized = true;
  }

  /// Handle platform method calls
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onAppPaused':
        await _handleAppPaused();
        break;
      case 'onAppResumed':
        await _handleAppResumed();
        break;
      case 'onAppDetached':
        await _handleAppDetached();
        break;
      default:
        debugPrint('⚠️ [AppLifecycle] Unknown method call: ${call.method}');
    }
  }

  /// Handle app paused (backgrounded)
  Future<void> _handleAppPaused() async {
    if (_currentState == AppLifecycleState.paused) return;

    _currentState = AppLifecycleState.paused;
    debugPrint('📱 [AppLifecycle] App paused - entering background mode');

    // Cancel any existing background timer
    _backgroundTimer?.cancel();

    // Start background timer to maintain connection
    _backgroundTimer = Timer(_backgroundTimeout, () async {
      debugPrint('⏰ [AppLifecycle] Background timeout reached - maintaining connection');
      await _maintainBackgroundConnection();
    });

    // Ensure background WebSocket is active
    await _ensureBackgroundConnection();
  }

  /// Handle app resumed (foregrounded)
  Future<void> _handleAppResumed() async {
    if (_currentState == AppLifecycleState.resumed) return;

    _currentState = AppLifecycleState.resumed;
    debugPrint('📱 [AppLifecycle] App resumed - entering foreground mode');

    // Cancel background timer
    _backgroundTimer?.cancel();

    // Delay reconnection to avoid conflicts
    _foregroundTimer?.cancel();
    _foregroundTimer = Timer(_foregroundReconnectDelay, () async {
      await _handleForegroundReconnection();
    });
  }

  /// Handle app detached (killed)
  Future<void> _handleAppDetached() async {
    debugPrint('📱 [AppLifecycle] App detached - cleaning up');
    await _cleanup();
  }

  /// Ensure background connection is active
  Future<void> _ensureBackgroundConnection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatToken = prefs.getString('chat_token');

      if (chatToken != null) {
        debugPrint('🔌 [AppLifecycle] Ensuring background WebSocket connection...');
        await BackgroundWebSocketService.startBackgroundService(chatToken);
      } else {
        debugPrint('⚠️ [AppLifecycle] No chat token available for background connection');
      }
    } catch (e) {
      debugPrint('❌ [AppLifecycle] Failed to ensure background connection: $e');
    }
  }

  /// Maintain background connection
  Future<void> _maintainBackgroundConnection() async {
    try {
      debugPrint('🔄 [AppLifecycle] Maintaining background connection...');

      // Ensure background service is still running
      await _ensureBackgroundConnection();

      // Schedule next maintenance check
      _backgroundTimer = Timer(_backgroundTimeout, () async {
        await _maintainBackgroundConnection();
      });
    } catch (e) {
      debugPrint('❌ [AppLifecycle] Failed to maintain background connection: $e');
    }
  }

  /// Handle foreground reconnection
  Future<void> _handleForegroundReconnection() async {
    try {
      debugPrint('🔄 [AppLifecycle] Handling foreground reconnection...');

      // The main WebSocket service will handle its own reconnection
      // We just need to ensure background service is still active
      await _ensureBackgroundConnection();
    } catch (e) {
      debugPrint('❌ [AppLifecycle] Failed to handle foreground reconnection: $e');
    }
  }

  /// Cleanup resources
  Future<void> _cleanup() async {
    _backgroundTimer?.cancel();
    _foregroundTimer?.cancel();

    // Don't disconnect background service on app kill
    // Let it continue running for notifications
    debugPrint('🧹 [AppLifecycle] Cleanup completed');
  }

  /// Get current app state
  AppLifecycleState get currentState => _currentState;

  /// Check if app is in background
  bool get isInBackground => _currentState == AppLifecycleState.paused;

  /// Check if app is in foreground
  bool get isInForeground => _currentState == AppLifecycleState.resumed;
}

/// App lifecycle states
enum AppLifecycleState {
  resumed,
  paused,
  detached,
}
