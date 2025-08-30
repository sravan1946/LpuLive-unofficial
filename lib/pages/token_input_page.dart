import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../models/user_models.dart';
import '../services/chat_services.dart';
import 'webview_login_page.dart';
import 'chat_home_page.dart';

class TokenInputApp extends StatelessWidget {
  const TokenInputApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LPU Live - Token Setup',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const TokenInputScreen(),
    );
  }
}

class TokenInputScreen extends StatefulWidget {
  const TokenInputScreen({super.key});

  @override
  State<TokenInputScreen> createState() => _TokenInputScreenState();
}

class _TokenInputScreenState extends State<TokenInputScreen> {
  final TextEditingController _tokenController = TextEditingController();
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null && clipboardData!.text!.isNotEmpty) {
        setState(() {
          _tokenController.text = clipboardData.text!;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = 'Clipboard is empty';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to paste from clipboard: $e';
      });
    }
  }

  Future<void> _submitToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a token';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    await _processToken(token);

    if (currentUser != null) {
      await TokenStorage.saveToken(token);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MyApp()),
        );
      }
    } else {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Invalid token. Please check and try again.';
      });
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LPU Live - Setup'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            const Icon(
              Icons.chat,
              size: 80,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 32),
            const Text(
              'Welcome to LPU Live Chat',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Please enter your authentication token to continue',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _tokenController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Authentication Token',
                hintText: 'Paste your base64 encoded token here...',
                errorText: _errorMessage,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste),
                  onPressed: _pasteFromClipboard,
                  tooltip: 'Paste from clipboard',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(Icons.content_paste),
                    label: const Text('Paste from Clipboard'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isProcessing ? null : _submitToken,
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Continue to Chat'),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.web),
              label: const Text('Login via Website'),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const WebViewLoginScreen()),
                );
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}