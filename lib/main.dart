import 'package:flutter/material.dart';
import 'dart:convert';
import 'models/user_models.dart';
import 'services/chat_services.dart';
import 'pages/token_input_page.dart';
import 'pages/chat_home_page.dart';
import 'pages/splash_page.dart';
import 'theme.dart';

class TokenValidationApp extends StatelessWidget {
  const TokenValidationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: lpuTheme,
      darkTheme: lpuDarkTheme,
      themeMode: ThemeMode.system,
      home: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFFFFE9D6), Colors.white],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 24),
                Text(
                  'Validating your session...',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                SizedBox(height: 8),
                Text(
                  'Please wait',
                  style: TextStyle(fontSize: 14, color: Colors.black38),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _processToken(String token) async {}

Future<bool> _validateToken(String token) async {
  try {
    final decodedBytes = base64Decode(token);
    final decodedString = utf8.decode(decodedBytes);
    final urlDecodedString = Uri.decodeFull(decodedString);
    final jsonData = jsonDecode(urlDecodedString);
    currentUser = User.fromJson(jsonData);
    return true;
  } catch (e) {
    return false;
  }
}

void main() async {
  print('🚀 App starting...');
  WidgetsFlutterBinding.ensureInitialized();

  // Check for saved token
  final savedToken = await TokenStorage.getToken();
  print('💾 Saved token found: ${savedToken != null ? "YES" : "NO"}');

  if (savedToken != null) {
    await _processToken(savedToken);

    if (currentUser != null) {
      // Show loading screen while validating token
      print('⏳ Showing validation loading screen...');
      runApp(const TokenValidationApp());

      // Show animated splash then validate in parallel and route
      runApp(const SplashApp());
      final isTokenValid = await _validateToken(savedToken);
      if (isTokenValid) {
        print('✅ Token validated, launching main app');
        runApp(const MyApp());
        return;
      } else {
        print('🚪 Token invalid/expired, clearing and showing login');
        await TokenStorage.clearToken();
        currentUser = null;
        print('🔐 Showing login screen after auto-logout');
        runApp(const TokenInputApp(autoLoggedOut: true));
        return;
      }
    } else {
      print('❌ Saved token invalid, clearing and showing login');
      await TokenStorage.clearToken();
      print('🔐 Showing login screen after auto-logout');
      runApp(const TokenInputApp(autoLoggedOut: true));
      return;
    }
  }

  print('🔐 No valid token, showing login screen');
  runApp(const TokenInputApp(autoLoggedOut: false));
}

class SplashApp extends StatelessWidget {
  const SplashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: lpuTheme,
      darkTheme: lpuDarkTheme,
      themeMode: ThemeMode.system,
      routes: {'/login': (_) => const TokenInputApp()},
      home: const SplashPage(),
    );
  }
}
