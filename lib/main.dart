import 'package:flutter/material.dart';
import 'dart:convert';
import 'models/user_models.dart';
import 'services/chat_services.dart';
import 'pages/token_input_page.dart';
import 'pages/chat_home_page.dart';

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

void main() async {
  print('🚀 App starting...');
  WidgetsFlutterBinding.ensureInitialized();

  // Check for saved token
  final savedToken = await TokenStorage.getToken();
  print('💾 Saved token found: ${savedToken != null ? "YES" : "NO"}');

  if (savedToken != null) {
    await _processToken(savedToken);

    if (currentUser != null) {
      print('✅ Using saved token, launching main app');
      runApp(const MyApp());
      return;
    } else {
      print('❌ Saved token invalid, clearing and showing login');
      await TokenStorage.clearToken();
    }
  }

  print('🔐 No valid token, showing login screen');
  runApp(const TokenInputApp());
}