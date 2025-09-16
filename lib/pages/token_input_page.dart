// Dart imports:
import 'dart:convert';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Project imports:
import '../models/current_user_state.dart';
import '../models/user_models.dart';
import '../providers/theme_provider.dart';
import '../services/chat_services.dart';
import '../theme.dart';
import '../widgets/app_toast.dart';
import 'chat_home_page.dart';
import 'webview_login_page.dart';

class TokenInputApp extends StatelessWidget {
  const TokenInputApp({super.key, this.autoLoggedOut = false});

  final bool autoLoggedOut;

  @override
  Widget build(BuildContext context) {
    print('🔐 TokenInputApp built - login screen shown');
    return ThemeProvider(
      themeService: globalThemeService,
      child: AnimatedBuilder(
        animation: globalThemeService,
        builder: (context, child) {
          return MaterialApp(
            title: 'LPU Live - Login',
            theme: lpuTheme,
            darkTheme: lpuDarkTheme,
            themeMode: globalThemeService.themeMode,
            home: UnifiedLoginScreen(autoLoggedOut: autoLoggedOut),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({super.key, this.autoLoggedOut = false});

  final bool autoLoggedOut;

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> {
  final TextEditingController _tokenController = TextEditingController();
  bool _isProcessing = false;
  bool _hasShownLogoutMessage = false;
  String? _errorMessage;
  bool _showTokenInput = false;

  @override
  void initState() {
    super.initState();
    // Show logout notification only if user was automatically logged out
    if (widget.autoLoggedOut) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_hasShownLogoutMessage) {
          _showLogoutNotification();
          _hasShownLogoutMessage = true;
        }
      });
    }
  }

  void _showLogoutNotification() {
    showAppToast(
      context,
      'Your session has expired. Please login again.',
      type: ToastType.warning,
      duration: const Duration(seconds: 4),
    );
  }

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
      setCurrentUser(User.fromJson(jsonData));
    } catch (e) {
      setCurrentUser(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('LPU Live - Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Container(
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.primary,
                    scheme.primary.withValues(alpha: 0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Icon(Icons.forum, color: Colors.white, size: 36),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to LPU Live Chat',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose your preferred login method',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Primary Option: Website Login
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star_rounded, color: scheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Recommended: Login via Website',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary,
                                ),
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Note: This will log you out from other devices.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFF58220),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'How to use: Click the button below and login with your university account.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () async {
                        print('🌐 Starting webview login process...');
                        // Clear local storage before opening webview
                        final navigator = Navigator.of(context);
                        await TokenStorage.clearToken();
                        print('🗑️ Local storage cleared');
                        print('🚀 Navigating to WebViewLoginScreen');
                        navigator.pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const WebViewLoginScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.web),
                      label: const Text('Login via Website'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Secondary Option: Token Input
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.vpn_key_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Alternative: Use Auth Token',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurfaceVariant,
                                ),
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Alternative method: Takes more time but won\'t log you out from other devices.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
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
                          color: scheme.primaryContainer.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: scheme.primaryContainer),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'How to get your token:',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '1. Login to LPU Live website in your browser\n2. Install a browser extension to access localStorage\n3. Open the extension and go to lpulive.lpu.in storage\n4. Find the "AuthData" key and copy its value\n5. Paste the token below',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
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
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.paste),
                            onPressed: _pasteFromClipboard,
                            tooltip: 'Paste from clipboard',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _submitToken,
                        icon: _isProcessing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.arrow_forward_rounded),
                        label: Text(
                          _isProcessing ? 'Processing…' : 'Continue to Chat',
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
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
            ),

            const SizedBox(height: 32),
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
          const Text(
            '• ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
