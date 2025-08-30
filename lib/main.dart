import 'package:flutter/material.dart';
import 'dart:convert';
import 'models/user_models.dart';
import 'services/chat_services.dart';
import 'pages/token_input_page.dart';
import 'pages/chat_home_page.dart';

Future<void> _processToken(String token) async {
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

  } catch (e) {
    currentUser = null;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check for saved token
  final savedToken = await TokenStorage.getToken();

  if (savedToken != null) {
    await _processToken(savedToken);

    if (currentUser != null) {
      runApp(const MyApp());
      return;
    } else {
      await TokenStorage.clearToken();
    }
  }

  runApp(const TokenInputApp());
}