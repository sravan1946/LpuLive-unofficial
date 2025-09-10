import 'package:flutter/material.dart';
import 'dart:convert';
import 'models/user_models.dart';
import 'services/chat_services.dart';
import 'pages/token_input_page.dart';
import 'pages/chat_home_page.dart';
import 'pages/splash_page.dart';
import 'pages/get_started_page.dart';
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
            backgroundColor: colorScheme.surface,
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
                      color: textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait',
                    style: textTheme.bodySmall?.copyWith(
                      color: textTheme.bodySmall?.color?.withValues(
                        alpha: 0.55,
                      ),
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
  // Accept both raw JSON and base64-encoded JSON tokens, then validate with server
  String? chatToken;
  try {
    final Map<String, dynamic> jsonData = jsonDecode(token);
    currentUser = User.fromJson(jsonData);
    chatToken = currentUser?.chatToken;
  } catch (_) {
    try {
      final decodedBytes = base64Decode(token);
      final decodedString = utf8.decode(decodedBytes);
      final urlDecodedString = Uri.decodeFull(decodedString);
      final Map<String, dynamic> jsonData = jsonDecode(urlDecodedString);
      currentUser = User.fromJson(jsonData);
      chatToken = currentUser?.chatToken;
    } catch (e) {
      return false;
    }
  }

  if (chatToken == null || chatToken.isEmpty) return false;

  // Server-side validation: make a lightweight authenticated call
  try {
    final api = ChatApiService();
    await api.fetchContacts(chatToken).timeout(const Duration(seconds: 6));
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SplashApp());
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
      routes: {
        '/login': (_) => const TokenInputApp(),
        '/get-started': (_) => const GetStartedPage(),
      },
      home: const SplashPage(),
    );
  }
}
