import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/user_models.dart';
import '../services/chat_services.dart';
import 'token_input_page.dart';
import 'chat_home_page.dart';
import 'dart:developer' as developer;

class WebViewLoginScreen extends StatefulWidget {
  const WebViewLoginScreen({super.key});

  @override
  State<WebViewLoginScreen> createState() => _WebViewLoginScreenState();
}

class _WebViewLoginScreenState extends State<WebViewLoginScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isMonitoring = false;
  bool _isRedirecting = false;
  int _checkAttempts = 0;
  static const int _maxCheckAttempts = 30; // 30 seconds timeout

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _periodicUrlCheck() async {
    if (!mounted) return;

    try {
      // Get current URL
      final currentUrl = await _controller?.currentUrl();
      if (_controller == null) return;
      if (currentUrl != null) {
        bool isChatUrl =
            currentUrl.contains('/chat') ||
            currentUrl.contains('chat') ||
            currentUrl.contains('Chat') ||
            currentUrl.contains('CHAT');

        if (isChatUrl && !_isMonitoring) {
          _isMonitoring = true;
          _checkAttempts = 0;
          await _checkForAuthData();
        }
      }
    } catch (e) {
      // Silent error handling for periodic checks
    }

    // Schedule next check if still monitoring or if we might be on a chat page
    if (mounted && (_isMonitoring || _checkAttempts < _maxCheckAttempts)) {
      Future.delayed(const Duration(seconds: 3), _periodicUrlCheck);
    }
  }

  Future<void> _testJavaScript() async {
    try {
      const String testScript = '''
          (function() {
            try {
              console.log('JavaScript test: Hello from webview!');
              return 'JS_WORKING';
            } catch (e) {
              console.log('JavaScript test error:', e);
              return 'JS_ERROR:' + e.toString();
            }
          })();
        ''';

      final result = await _controller?.runJavaScriptReturningResult(
        testScript,
      );
      if (_controller == null) return;

      if (!result.toString().contains('JS_WORKING')) {
        setState(() {
          _errorMessage = 'JavaScript execution failed';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'JavaScript test failed: $e';
      });
    }
  }

  Future<void> _clearWebViewLocalStorage() async {
    try {
      // First test if JavaScript is working
      await _testJavaScript();

      const String clearScript = '''
          (function() {
            try {
              const beforeClear = localStorage.length;
              localStorage.clear();
              const afterClear = localStorage.length;
              return 'CLEARED_' + beforeClear + '_to_' + afterClear;
            } catch (e) {
              return 'ERROR:' + e.toString();
            }
          })();
        ''';

      final result = await _controller?.runJavaScriptReturningResult(
        clearScript,
      );
      if (_controller == null) return;

      if (result.toString().contains('ERROR')) {
        setState(() {
          _errorMessage =
              'Failed to clear webview localStorage: ${result.toString().substring(6)}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error clearing webview localStorage: $e';
      });
    }
  }

  @override
  void initState() {
    super.initState();

    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) async {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });

              // Clear localStorage immediately when page starts loading
              await _clearWebViewLocalStorage();
            },
            onPageFinished: (String url) async {
              // If we're in redirecting mode, don't change the loading state
              if (!_isRedirecting && _controller != null) {
                setState(() {
                  _isLoading = false;
                });
              }

              // Wait a bit for the page to be fully ready
              await Future.delayed(const Duration(milliseconds: 500));

              // Check if we've been redirected to /chat (more flexible detection)
              bool isChatUrl =
                  url.contains('/chat') ||
                  url.contains('chat') ||
                  url.endsWith('/chat') ||
                  url.contains('Chat') ||
                  url.contains('CHAT');

              if (isChatUrl && !_isRedirecting) {
                setState(() {
                  _isRedirecting = true;
                  _isLoading = false;
                  _errorMessage = null;
                });

                if (!_isMonitoring) {
                  _isMonitoring = true;
                  _checkAttempts = 0; // Reset attempts counter
                  // Wait a bit more before starting monitoring
                  await Future.delayed(const Duration(milliseconds: 1000));
                  await _checkForAuthData();
                }
              } else if (!isChatUrl && _isRedirecting) {
                setState(() {
                  _isRedirecting = false;
                  _isMonitoring = false;
                  _checkAttempts = 0;
                });
              } else {
                if (_isMonitoring && !isChatUrl) {
                  _isMonitoring = false;
                  _checkAttempts = 0; // Reset attempts counter
                }
              }
            },
            onWebResourceError: (WebResourceError error) {
              setState(() {
                _isLoading = false;
                _errorMessage = 'Failed to load page: ${error.description}';
              });
            },
            onNavigationRequest: (NavigationRequest request) {
              // Check if URL contains /chat (more robust detection)
              bool isChatUrl =
                  request.url.contains('/chat') ||
                  request.url.contains('chat') ||
                  request.url.endsWith('/chat') ||
                  request.url.contains('Chat') ||
                  request.url.contains('CHAT');

              if (isChatUrl) {
                setState(() {
                  _isRedirecting = true;
                  _isLoading = false;
                  _errorMessage = null;
                });

                // Start monitoring for auth data
                if (!_isMonitoring) {
                  _isMonitoring = true;
                  _checkAttempts = 0;
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) {
                      _checkForAuthData();
                    }
                  });
                }

                return NavigationDecision.navigate;
              }

              // Allow navigation to lpulive.lpu.in and its subdomains
              if (request.url.startsWith('https://lpulive.lpu.in')) {
                return NavigationDecision.navigate;
              }
              return NavigationDecision.prevent;
            },
            onUrlChange: (UrlChange change) {
              // Also check for /chat URLs in URL changes (for JavaScript redirects)
              if (change.url != null &&
                  (change.url!.contains('/chat') ||
                      change.url!.contains('chat'))) {
                setState(() {
                  _isRedirecting = true;
                  _isLoading = false;
                  _errorMessage = null;
                });

                // Start monitoring for auth data
                if (!_isMonitoring) {
                  _isMonitoring = true;
                  _checkAttempts = 0;
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) {
                      _checkForAuthData();
                    }
                  });
                }
              }
            },
          ),
        )
        ..loadRequest(Uri.parse('https://lpulive.lpu.in'));

      // Start periodic URL checking as backup
      Future.delayed(const Duration(seconds: 2), _periodicUrlCheck);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize webview: $e';
      });
      return;
    }
  }

  Future<void> _checkForAuthData() async {
    if (_checkAttempts >= _maxCheckAttempts) {
      setState(() {
        _isMonitoring = false;
        _isRedirecting = false;
        _errorMessage =
            'Login timeout: AuthData not found within 30 seconds. Please try again.';
      });
      return;
    }

    _checkAttempts++;

    const String script = '''
       (function() {
         try {
           console.log('🔧 JavaScript: Checking localStorage for auth data');
           console.log('🔧 JavaScript: localStorage available:', typeof localStorage !== 'undefined');

           if (typeof localStorage === 'undefined') {
             console.log('❌ JavaScript: localStorage is not available');
             return 'NO_LOCALSTORAGE';
           }

           // Check multiple possible key names
           const possibleKeys = ['AuthData', 'authData', 'auth_token', 'token', 'user_token'];
           let foundData = null;
           let foundKey = null;

           for (const key of possibleKeys) {
             const value = localStorage.getItem(key);
             console.log('🔧 JavaScript: Checking key "' + key + '":', value ? 'EXISTS (' + value.length + ' chars)' : 'NOT FOUND');

             if (value && value.length > 0 && value !== 'null' && value !== 'undefined') {
               foundData = value;
               foundKey = key;
               console.log('🔧 JavaScript: Found valid data in key "' + key + '"');
               break;
             }
           }

           if (foundData) {
             console.log('🔧 JavaScript: Auth data preview:', foundData.substring(0, 100) + '...');
             // Return the data with a success marker
             return 'SUCCESS:' + foundData;
           } else {
             // Check all localStorage keys and their values
             const allKeys = Object.keys(localStorage);
             console.log('🔧 JavaScript: All localStorage keys:', allKeys.join(', '));

             let keyValues = '';
             for (const key of allKeys) {
               const value = localStorage.getItem(key);
               const preview = value ? value.substring(0, 50) + (value.length > 50 ? '...' : '') : 'null';
               keyValues += key + '=' + preview + '; ';
             }
             console.log('🔧 JavaScript: Key values:', keyValues);

             return 'NO_AUTH_DATA_KEYS:' + allKeys.join(',');
           }
         } catch (e) {
           console.log('❌ JavaScript: Error accessing localStorage:', e.toString());
           return 'ERROR:' + e.toString();
         }
       })();
     ''';

    try {
      final result = await _controller?.runJavaScriptReturningResult(script);
      if (_controller == null) return;
      final authData = result.toString().replaceAll('"', '');

      if (authData.startsWith('SUCCESS:')) {
        final actualData = authData.substring(8); // Remove 'SUCCESS:' prefix
        await _processAuthData(actualData);
      } else if (authData.startsWith('ERROR:')) {
        setState(() {
          _errorMessage = 'JavaScript error: ${authData.substring(6)}';
          _isMonitoring = false;
          _isRedirecting = false;
        });
      } else if (authData.startsWith('NO_LOCALSTORAGE')) {
        setState(() {
          _errorMessage = 'localStorage not available in webview';
          _isMonitoring = false;
          _isRedirecting = false;
        });
      } else if (authData.startsWith('NO_AUTH_DATA_KEYS:')) {
        // AuthData not found yet, check again in 1 second
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && _isMonitoring) {
            _checkForAuthData();
          }
        });
      } else {
        // AuthData not found yet, check again in 1 second
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && _isMonitoring) {
            _checkForAuthData();
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error accessing localStorage: ${e.toString()}';
        _isMonitoring = false;
      });
    }
  }

  Future<void> _processAuthData(String authData) async {
    try {
      // Process the AuthData (assuming it's in the same format as before)
      await _processWebViewToken(authData);

      if (currentUser != null && mounted) {
        // Navigate to main app
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MyApp()),
        );
      } else {
        setState(() {
          _errorMessage =
              'Failed to process authentication data: Invalid format';
          _isMonitoring = false;
          _isRedirecting = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing authentication data: ${e.toString()}';
        _isMonitoring = false;
      });
    }
  }

  Future<void> _processWebViewToken(String tokenData) async {
    try {
      String processedToken = tokenData;

      // Try to decode if it's base64
      try {
        developer.log('🔄 Attempting base64 decode...', name: 'WebViewLogin');
        final decodedBytes = base64Decode(tokenData);
        processedToken = utf8.decode(decodedBytes);
        developer.log('✅ Base64 decode successful', name: 'WebViewLogin');
      } catch (e) {
        developer.log(
          '⚠️ Base64 decode failed, using as-is: $e',
          name: 'WebViewLogin',
        );
        // Token might not be base64 encoded, use as is
      }

      // Try URL decoding
      try {
        developer.log('🔄 Attempting URL decode...', name: 'WebViewLogin');
        final urlDecoded = Uri.decodeFull(processedToken);
        processedToken = urlDecoded;
        developer.log('✅ URL decode successful', name: 'WebViewLogin');
      } catch (e) {
        developer.log(
          '⚠️ URL decode failed, using as-is: $e',
          name: 'WebViewLogin',
        );
        // No URL decoding needed
      }

      developer.log(
        '📝 Processed token length: ${processedToken.length}',
        name: 'WebViewLogin',
      );
      developer.log(
        '📝 Processed token preview: ${processedToken.substring(0, min(50, processedToken.length))}...',
        name: 'WebViewLogin',
      );

      // Try to parse as JSON
      try {
        developer.log('🔄 Attempting JSON parse...', name: 'WebViewLogin');
        final jsonData = jsonDecode(processedToken);
        currentUser = User.fromJson(jsonData);
        developer.log(
          '✅ JSON parse successful! User created',
          name: 'WebViewLogin',
        );

        // Save the original token data
        await TokenStorage.saveToken(tokenData);
        developer.log('💾 Token saved to storage', name: 'WebViewLogin');
      } catch (e) {
        developer.log(
          '❌ JSON parse failed, trying raw token: $e',
          name: 'WebViewLogin',
        );
        // If it's not JSON, it might be the raw token
        try {
          final jsonData = jsonDecode(tokenData);
          currentUser = User.fromJson(jsonData);
          await TokenStorage.saveToken(tokenData);
          developer.log(
            '✅ Raw token JSON parse successful!',
            name: 'WebViewLogin',
          );
        } catch (e2) {
          developer.log(
            '💥 Both JSON parse attempts failed: $e2',
            name: 'WebViewLogin',
          );
          setState(() {
            _errorMessage = 'Invalid token format received';
          });
          return;
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing login token';
        _isRedirecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LPU Live - Web Login'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller?.reload();
            },
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const TokenInputApp()),
              );
            },
            tooltip: 'Back to Token Input',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Only show WebView when not redirecting
          if (!_isRedirecting && _controller != null)
            WebViewWidget(controller: _controller!)
          else ...[
            // Show redirecting screen and keep WebView running invisibly
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Redirecting...'),
                    SizedBox(height: 8),
                    Text(
                      'Collecting authentication data...',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            // Keep WebView running invisibly to collect auth data
            Opacity(
              opacity: 0.0,
              child: IgnorePointer(
                child: _controller != null
                    ? WebViewWidget(controller: _controller!)
                    : Container(),
              ),
            ),
          ],
          if (_isLoading && !_isRedirecting)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading login page...'),
                  ],
                ),
              ),
            ),

          if (_errorMessage != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.red.shade100,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red.shade700),
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
