import 'package:flutter/material.dart';
import 'pages/splash_page.dart';
import 'theme.dart';
import 'services/theme_controller.dart';
import 'providers/theme_provider.dart';

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
  await ThemeController.instance.load();

  runApp(const AppRoot());
}
