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
    print('🔐 TokenInputApp built - login screen shown');
    return MaterialApp(
      title: 'LPU Live - Login',
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
      home: const UnifiedLoginScreen(),
    );
  }
}

class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({super.key});

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> {
  final TextEditingController _tokenController = TextEditingController();
  bool _isProcessing = false;
  String? _errorMessage;
  bool _showTokenInput = false;

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
        title: const Text('LPU Live - Login'),
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
              'Choose your preferred login method',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Primary Option: Website Login
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.deepPurple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.deepPurple),
                      const SizedBox(width: 8),
                      const Text(
                        'Recommended: Login via Website',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                   const SizedBox(height: 12),
                   const Text(
                     'Note: This will log you out from other devices.',
                     style: TextStyle(
                       fontSize: 14,
                       color: Colors.orange,
                       fontWeight: FontWeight.w500,
                     ),
                   ),
                   const SizedBox(height: 16),
                   Text(
                     'How to use: Click the button below and login with your university account.',
                     style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                   ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () async {
                      print('🌐 Starting webview login process...');
                      // Clear local storage before opening webview
                      await TokenStorage.clearToken();
                      print('🗑️ Local storage cleared');
                      if (mounted) {
                        print('🚀 Navigating to WebViewLoginScreen');
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const WebViewLoginScreen()),
                        );
                      }
                    },
                    icon: const Icon(Icons.web),
                    label: const Text('Login via Website'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Secondary Option: Token Input
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.vpn_key, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text(
                        'Alternative: Use Auth Token',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                   const SizedBox(height: 12),
                   Text(
                     'Alternative method: Takes more time but won\'t log you out from other devices.',
                     style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                   ),
                  const SizedBox(height: 16),
                   if (!_showTokenInput) ...[
                     OutlinedButton.icon(
                       onPressed: () {
                         setState(() {
                           _showTokenInput = true;
                         });
                       },
                       icon: const Icon(Icons.expand_more),
                       label: const Text('Show Token Input'),
                       style: OutlinedButton.styleFrom(
                         minimumSize: const Size(double.infinity, 50),
                       ),
                     ),
                   ] else ...[
                     Container(
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(
                         color: Colors.blue.shade50,
                         borderRadius: BorderRadius.circular(8),
                         border: Border.all(color: Colors.blue.shade200),
                       ),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           const Text(
                             'How to get your token:',
                             style: TextStyle(
                               fontSize: 16,
                               fontWeight: FontWeight.bold,
                               color: Colors.blue,
                             ),
                           ),
                           const SizedBox(height: 8),
                            Text(
                              '1. Login to LPU Live website in your browser\n2. Install a browser extension to access localStorage\n3. Open the extension and go to lpulive.lpu.in storage\n4. Find the "AuthData" key and copy its value\n5. Paste the token below',
                              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                            ),
                         ],
                       ),
                     ),
                     const SizedBox(height: 16),
                     TextField(
                       controller: _tokenController,
                       maxLines: 5,
                       decoration: InputDecoration(
                         labelText: 'Authentication Token',
                         hintText: 'Paste your token here...',
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
                     ElevatedButton(
                       onPressed: _isProcessing ? null : _submitToken,
                       style: ElevatedButton.styleFrom(
                         minimumSize: const Size(double.infinity, 48),
                       ),
                       child: _isProcessing
                           ? const SizedBox(
                               height: 20,
                               width: 20,
                               child: CircularProgressIndicator(strokeWidth: 2),
                             )
                           : const Text('Continue to Chat'),
                     ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showTokenInput = false;
                          _tokenController.clear();
                          _errorMessage = null;
                        });
                      },
                      icon: const Icon(Icons.expand_less),
                      label: const Text('Hide Token Input'),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class BulletPoint extends StatelessWidget {
  final String text;

  const BulletPoint({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}