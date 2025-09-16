// Flutter imports:
import 'package:flutter/material.dart';

// Project imports:
import 'pages/splash_page.dart';
import 'providers/theme_provider.dart';
import 'theme.dart';

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

  runApp(const AppRoot());
}
