// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Project imports:
import 'pages/splash_page.dart';
import 'providers/theme_provider.dart';
import 'services/app_lifecycle_manager.dart';
import 'services/background_websocket_service.dart';
import 'theme.dart';

// import 'package:workmanager/workmanager.dart';


final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      themeService: globalThemeService,
      child: AnimatedBuilder(
        animation: globalThemeService,
        builder: (context, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: true,
            navigatorKey: _navigatorKey,
            theme: lpuTheme,
            darkTheme: lpuDarkTheme,
            themeMode: globalThemeService.themeMode,
            home: const SplashPage(),
          );
        },
      ),
    );
  }
}

void main() async {
  print('🚀 App starting...');
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize background services
  await _initializeBackgroundServices();

  runApp(const AppRoot());
}

  Future<void> _initializeBackgroundServices() async {
    // Initialize background services (simplified approach)
    debugPrint('🔧 [Main] Initializing background services...');

    // Initialize local notifications
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        print('📱 Notification tapped: ${response.payload}');
      },
    );

    // Initialize background service
    await BackgroundWebSocketService.initialize();

    // Initialize app lifecycle manager
    await AppLifecycleManager.instance.initialize();
  }
