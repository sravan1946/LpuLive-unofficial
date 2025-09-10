import 'package:flutter/material.dart';
import 'pages/splash_page.dart';
import 'theme.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: true,
      navigatorKey: _navigatorKey,
      theme: lpuTheme,
      darkTheme: lpuDarkTheme,
      themeMode: ThemeMode.system,
      home: const SplashPage(),
    );
  }
}

void main() async {
  print('🚀 App starting...');
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const AppRoot());
}

