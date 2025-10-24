# Background WebSocket Connection Solution

This document explains the comprehensive solution implemented to maintain WebSocket connections when the app is closed or the phone is locked.

## Problem

The original issue was that WebSocket connections would fail when:
- The app is closed/minimized
- The phone is locked
- The device goes into deep sleep mode

This resulted in error messages like:
```
❌ [WebSocket] Stream error: WebSocketChannelException: SocketException: Failed host lookup: 'lpulive.lpu.in' (OS Error: No address associated with hostname, errno = 7)
```

## Solution Overview

The solution implements a multi-layered approach:

1. **Background WebSocket Service** - Maintains connections in the background
2. **App Lifecycle Management** - Handles foreground/background transitions
3. **Native Platform Integration** - Android/iOS specific implementations
4. **Smart Reconnection** - Intelligent retry logic with exponential backoff
5. **Local Notifications** - Notify users of new messages when app is closed

## Architecture

### 1. Background WebSocket Service (`background_websocket_service.dart`)

**Key Features:**
- Maintains WebSocket connections when app is closed
- Sends keep-alive pings every 5 minutes
- Handles reconnection with exponential backoff
- Shows local notifications for new messages
- Works with WorkManager for periodic background tasks

**Implementation:**
```dart
class BackgroundWebSocketService {
  static Future<void> connect(String chatToken) async {
    // Establishes background WebSocket connection
    // Handles message processing and notifications
  }
  
  static Future<void> _showMessageNotification(Map<String, dynamic> messageData) async {
    // Shows local notification for new messages
  }
}
```

### 2. App Lifecycle Manager (`app_lifecycle_manager.dart`)

**Key Features:**
- Monitors app state transitions (foreground/background)
- Coordinates between main WebSocket and background service
- Handles reconnection when app returns to foreground
- Manages background timeout and maintenance

**Implementation:**
```dart
class AppLifecycleManager {
  Future<void> _handleAppPaused() async {
    // App goes to background - ensure background service is active
  }
  
  Future<void> _handleAppResumed() async {
    // App returns to foreground - coordinate reconnection
  }
}
```

### 3. Enhanced Main WebSocket Service

**Key Features:**
- Integrates with background service
- Stores chat token for background use
- Coordinates disconnection with background service
- Maintains existing functionality

**Changes Made:**
```dart
Future<void> connect(String chatToken) async {
  // Store token for background service
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('chat_token', chatToken);
  
  // Start background WebSocket service
  await BackgroundWebSocketService.connect(chatToken);
  
  // Continue with normal connection...
}
```

### 4. Native Platform Integration

#### Android Implementation

**Permissions Added:**
```xml
<!-- Background service permissions -->
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

**Services Added:**
```xml
<!-- Background service for WebSocket maintenance -->
<service
    android:name="be.tramckrijte.workmanager.WorkManagerService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="dataSync" />
```

**Lifecycle Handler:**
```kotlin
class LifecycleHandler : Application.ActivityLifecycleCallbacks {
    override fun onActivityResumed(activity: Activity) {
        methodChannel?.invokeMethod("onAppResumed", null)
    }
    
    override fun onActivityPaused(activity: Activity) {
        methodChannel?.invokeMethod("onAppPaused", null)
    }
}
```

#### iOS Implementation

**Background Modes:**
```xml
<key>UIBackgroundModes</key>
<array>
    <string>background-processing</string>
    <string>background-fetch</string>
    <string>remote-notification</string>
</array>
```

### 5. Dependencies Added

```yaml
# App lifecycle management for background handling
flutter_app_lifecycle: ^0.0.4

# Background task handling
workmanager: ^0.5.2

# Local notifications for background messages
flutter_local_notifications: ^17.2.2
```

## How It Works

### 1. App Startup
1. Initialize background services in `main.dart`
2. Set up WorkManager for periodic background tasks
3. Initialize local notifications
4. Start app lifecycle monitoring

### 2. WebSocket Connection
1. Main WebSocket service connects normally
2. Chat token is stored in SharedPreferences
3. Background WebSocket service starts with same token
4. Both services maintain independent connections

### 3. App Goes to Background
1. Lifecycle manager detects app pause
2. Background service continues running
3. Main WebSocket may disconnect (normal behavior)
4. Background service sends keep-alive pings every 5 minutes
5. New messages trigger local notifications

### 4. App Returns to Foreground
1. Lifecycle manager detects app resume
2. Main WebSocket reconnects automatically
3. Background service continues running
4. User sees real-time messages again

### 5. App is Closed/Killed
1. Background service continues running via WorkManager
2. Periodic tasks (every 15 minutes) check connectivity
3. Reconnects if needed
4. Shows notifications for new messages
5. User can tap notification to reopen app

## Benefits

1. **Persistent Connections** - WebSocket stays connected even when app is closed
2. **Real-time Notifications** - Users get notified of new messages immediately
3. **Battery Efficient** - Smart reconnection and keep-alive mechanisms
4. **Platform Optimized** - Uses native Android/iOS background capabilities
5. **Fallback Handling** - Multiple layers of reconnection logic
6. **User Experience** - Seamless transition between foreground/background

## Configuration

### Android
- Requires Android 6.0+ (API 23+)
- Needs notification permissions for Android 13+
- Uses WorkManager for reliable background execution

### iOS
- Requires iOS 13.0+
- Uses background processing capabilities
- Respects iOS background execution limits

## Monitoring and Debugging

The solution includes comprehensive logging:
- `🔌 [WebSocket]` - Connection events
- `📱 [AppLifecycle]` - App state transitions
- `🔄 [BackgroundWebSocket]` - Background service events
- `📡 [WebSocket]` - Message handling
- `❌ [WebSocket]` - Error conditions

## Limitations

1. **Battery Usage** - Background connections consume battery
2. **Platform Limits** - iOS has stricter background execution limits
3. **Network Dependency** - Requires stable internet connection
4. **Permission Requirements** - Needs notification and background permissions

## Future Improvements

1. **Adaptive Keep-alive** - Adjust ping frequency based on usage patterns
2. **Connection Pooling** - Share connections between services
3. **Offline Queue** - Queue messages when offline
4. **Analytics** - Track connection stability and performance
5. **User Preferences** - Allow users to configure background behavior

## Testing

To test the solution:

1. **Background Test:**
   - Connect to WebSocket
   - Minimize app or lock phone
   - Send message from another device
   - Verify notification appears

2. **Reconnection Test:**
   - Connect to WebSocket
   - Close app completely
   - Wait 15 minutes
   - Send message from another device
   - Verify notification appears

3. **Foreground Test:**
   - Connect to WebSocket
   - Minimize app
   - Restore app
   - Verify connection is active

## Troubleshooting

### Common Issues:

1. **No Notifications:**
   - Check notification permissions
   - Verify background service is running
   - Check device battery optimization settings

2. **Connection Drops:**
   - Check network connectivity
   - Verify server is accessible
   - Check device background app restrictions

3. **High Battery Usage:**
   - Adjust keep-alive frequency
   - Check for connection leaks
   - Monitor background task frequency

This solution provides a robust, production-ready implementation for maintaining WebSocket connections in the background while respecting platform limitations and user experience considerations.

