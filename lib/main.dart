import 'package:flutter/material.dart';
import 'dart:convert';
import 'models/user_models.dart';
import 'services/chat_services.dart';
import 'pages/token_input_page.dart';
import 'pages/chat_home_page.dart';
import 'pages/splash_page.dart';

class TokenValidationApp extends StatelessWidget {
  const TokenValidationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.blue.shade50,
                Colors.white,
              ],
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
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Please wait',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black38,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _processToken(String token) async {
  print('🔧 Processing token in main.dart...');
  try {
    // Decode base64 token
    final decodedBytes = base64Decode(token);
    final decodedString = utf8.decode(decodedBytes);

    // URL decode the string first
    final urlDecodedString = Uri.decodeFull(decodedString);

    // Parse JSON
    final jsonData = jsonDecode(urlDecodedString);

    // Create User object
    currentUser = User.fromJson(jsonData);
    print('✅ User created successfully in main.dart: ${currentUser!.name}');

  } catch (e) {
    print('❌ Error processing token in main.dart: $e');
    currentUser = null;
  }
}

Future<bool> _validateToken(String storedToken) async {
  print('🔍 Validating token by fetching contacts...');

  // Extract the actual ChatToken from the stored token
  String actualToken;
  try {
    // Decode base64 token
    final decodedBytes = base64Decode(storedToken);
    final decodedString = utf8.decode(decodedBytes);

    // URL decode the string first
    final urlDecodedString = Uri.decodeFull(decodedString);

    // Parse JSON
    final jsonData = jsonDecode(urlDecodedString);

    // Extract the ChatToken field
    actualToken = jsonData['ChatToken'] ?? '';
    if (actualToken.isEmpty) {
      print('🚪 Invalid token format - no ChatToken found');
      return false;
    }

    print('🔑 Extracted ChatToken for validation');
  } catch (e) {
    print('🚪 Failed to decode stored token: $e');
    return false;
  }

  try {
    final chatService = ChatApiService();
    await chatService.fetchContacts(actualToken);
    print('✅ Token is valid');
    return true;
  } catch (e) {
    print('❌ Token validation failed: $e');
    print('❌ Token validation - checking for invalid token patterns...');
    print('❌ Contains "Invalid ChatToken format": ${e.toString().contains('Invalid ChatToken format')}');
    print('❌ Contains "Invalid chat_token": ${e.toString().contains('Invalid chat_token')}');
    print('❌ Contains "400": ${e.toString().contains('400')}');
    print('❌ Contains "404": ${e.toString().contains('404')}');

    // Check if it's a 401 unauthorized error
    if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
      print('🚪 Token expired (401), user needs to login again');
      return false;
    }

    // Check if it's an invalid token error (400/404 with various invalid token messages)
    if (e.toString().contains('Invalid ChatToken format') ||
        e.toString().contains('Invalid chat_token') ||
        (e.toString().contains('400') && e.toString().contains('Invalid')) ||
        (e.toString().contains('404') && e.toString().contains('Invalid'))) {
      print('🚪 Invalid token (400/404), user needs to login again');

      // Show logout notification to user
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // We can't show snackbar here since we don't have a BuildContext
        // The notification will be shown when the login screen loads
        print('📢 User will be notified: Your session has expired. Please login again.');
      });

      return false;
    }

    // Check for network-related errors
    if (e.toString().contains('SocketException') ||
        e.toString().contains('Connection refused') ||
        e.toString().contains('Network is unreachable') ||
        e.toString().contains('Failed host lookup')) {
      print('🌐 Network error during validation, allowing offline access');
      return true; // Allow offline access
    }

    // For other server errors (500, 502, etc.), allow user to proceed
    print('⚠️ Server error during validation, allowing user to proceed');
    return true;
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
      routes: {
        '/login': (_) => const TokenInputApp(),
      },
      home: const SplashPage(),
    );
  }
}