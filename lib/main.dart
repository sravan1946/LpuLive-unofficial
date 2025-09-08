import 'package:flutter/material.dart';
import 'dart:convert';
import 'models/user_models.dart';
import 'services/chat_services.dart';
import 'pages/token_input_page.dart';
import 'pages/chat_home_page.dart';
import 'pages/splash_page.dart';
import 'theme.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

class TokenValidationApp extends StatelessWidget {
  const TokenValidationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: lpuTheme,
      darkTheme: lpuDarkTheme,
      themeMode: ThemeMode.system,
      home: Builder(
        builder: (context) {
          final colorScheme = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;
          return Scaffold(
            backgroundColor: colorScheme.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Validating your session...',
                    style: textTheme.bodyMedium?.copyWith(
                      color: textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait',
                    style: textTheme.bodySmall?.copyWith(
                      color: textTheme.bodySmall?.color?.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

Future<void> _processToken(String token) async {
  try {
    // Try parsing as raw JSON first
    final Map<String, dynamic> jsonData = jsonDecode(token);
    currentUser = User.fromJson(jsonData);
    return;
  } catch (_) {
    // Fallback: try base64 -> utf8 -> URL decode -> JSON
    try {
      final decodedBytes = base64Decode(token);
      final decodedString = utf8.decode(decodedBytes);
      final urlDecodedString = Uri.decodeFull(decodedString);
      final Map<String, dynamic> jsonData = jsonDecode(urlDecodedString);
      currentUser = User.fromJson(jsonData);
      return;
    } catch (e) {
      currentUser = null;
    }
  }
}

Future<bool> _validateToken(String token) async {
  // Accept both raw JSON and base64-encoded JSON tokens
  try {
    final Map<String, dynamic> jsonData = jsonDecode(token);
    currentUser = User.fromJson(jsonData);
    return true;
  } catch (_) {
    try {
      final decodedBytes = base64Decode(token);
      final decodedString = utf8.decode(decodedBytes);
      final urlDecodedString = Uri.decodeFull(decodedString);
      final Map<String, dynamic> jsonData = jsonDecode(urlDecodedString);
      currentUser = User.fromJson(jsonData);
      return true;
    } catch (e) {
      return false;
    }
  }
}

void main() async {
  print('🚀 App starting...');
  WidgetsFlutterBinding.ensureInitialized();

  // Show validation screen immediately for first frame
  runApp(const TokenValidationApp());

  // Do token flow after first frame
  Future.microtask(() async {
    final savedToken = await TokenStorage.getToken();
    print('💾 Saved token found: ${savedToken != null ? "YES" : "NO"}');

    if (savedToken != null) {
      await _processToken(savedToken);

      if (currentUser != null) {
        // Validate token in background, keep the validation screen visible
        const minimumVisibleMs = 900;
        final startedAt = DateTime.now();
        final isTokenValid = await _validateToken(savedToken);
        final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
        if (elapsed < minimumVisibleMs) {
          await Future.delayed(Duration(milliseconds: minimumVisibleMs - elapsed));
        }
        if (isTokenValid) {
          print('✅ Token validated, launching main app');
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ChatHomePage()),
            (route) => false,
          );
          return;
        } else {
          print('🚪 Token invalid/expired, clearing and showing login');
          await TokenStorage.clearToken();
          currentUser = null;
          print('🔐 Showing login screen after auto-logout');
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const UnifiedLoginScreen(autoLoggedOut: true)),
            (route) => false,
          );
          return;
        }
      } else {
        print('❌ Saved token invalid, clearing and showing login');
        await TokenStorage.clearToken();
        print('🔐 Showing login screen after auto-logout');
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const UnifiedLoginScreen(autoLoggedOut: true)),
          (route) => false,
        );
        return;
      }
    }

    print('🔐 No valid token, showing login screen');
    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const UnifiedLoginScreen(autoLoggedOut: false)),
      (route) => false,
    );
  });
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
