import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/user_models.dart';
import '../services/chat_services.dart';
import 'token_input_page.dart';
import 'chat_home_page.dart';

class WebViewLoginScreen extends StatefulWidget {
  const WebViewLoginScreen({super.key});

  @override
  State<WebViewLoginScreen> createState() => _WebViewLoginScreenState();
}

class _WebViewLoginScreenState extends State<WebViewLoginScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _injectLoginInterceptor();
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Failed to load page: ${error.description}';
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://lpulive.lpu.in') ||
                request.url.contains('/api/auth')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://lpulive.lpu.in'));
  }

  void _injectLoginInterceptor() {
    const String script = '''
      (function() {
        const originalFetch = window.fetch;
        window.fetch = function(...args) {
          const url = args[0];
          if (typeof url === 'string' && url.includes('/api/auth')) {
            return originalFetch.apply(this, args).then(response => {
              return response.clone().text().then(text => {
                window.flutter_inappwebview.callHandler('authResponse', {
                  status: response.status,
                  body: text,
                  url: url
                });
                return response;
              });
            }).catch(error => {
              window.flutter_inappwebview.callHandler('authError', error.toString());
              throw error;
            });
          }
          return originalFetch.apply(this, args);
        };

        const originalXHR = window.XMLHttpRequest;
        window.XMLHttpRequest = function() {
          const xhr = new originalXHR();
          const originalOpen = xhr.open;
          const originalSend = xhr.send;

          xhr.open = function(method, url, ...rest) {
            if (url.includes('/api/auth')) {
              this._isAuthRequest = true;
            }
            return originalOpen.apply(this, [method, url, ...rest]);
          };

          xhr.send = function(body) {
            if (this._isAuthRequest) {
              // Handle request
            }
            return originalSend.apply(this, [body]);
          };

          const originalOnLoad = xhr.onload;
          const originalOnError = xhr.onerror;

          xhr.onload = function() {
            if (this._isAuthRequest) {
              window.flutter_inappwebview.callHandler('authResponse', {
                status: this.status,
                body: this.responseText,
                url: this.responseURL
              });
            }
            if (originalOnLoad) originalOnLoad.apply(this);
          };

          xhr.onerror = function() {
            if (this._isAuthRequest) {
              window.flutter_inappwebview.callHandler('authError', 'XHR request failed');
            }
            if (originalOnError) originalOnError.apply(this);
          };

          return xhr;
        };
      })();
    ''';

    _controller.runJavaScript(script);

    _controller.addJavaScriptChannel(
      'authResponse',
      onMessageReceived: (JavaScriptMessage message) {
        _handleAuthResponse(message.message);
      },
    );

    _controller.addJavaScriptChannel(
      'authError',
      onMessageReceived: (JavaScriptMessage message) {
        setState(() {
          _errorMessage = 'Login failed: ${message.message}';
        });
      },
    );
  }

  void _handleAuthResponse(String message) {
    try {
      final Map<String, dynamic> response = jsonDecode(message);
      final int status = response['status'];
      final String body = response['body'];

      if (status == 200) {
        try {
          final Map<String, dynamic> jsonResponse = jsonDecode(body);
          if (jsonResponse.containsKey('error')) {
            setState(() {
              _errorMessage = 'Authentication failed: ${jsonResponse['error']}';
            });
          } else {
            _processWebViewToken(body);
          }
        } catch (e) {
          _processWebViewToken(body);
        }
      } else {
        setState(() {
          _errorMessage = 'Login failed with status: $status';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing login response';
      });
    }
  }

  Future<void> _processWebViewToken(String tokenData) async {
    try {
      String processedToken = tokenData;
      try {
        final decodedBytes = base64Decode(tokenData);
        processedToken = utf8.decode(decodedBytes);
      } catch (e) {
        // Token is not base64 encoded
      }

      try {
        final urlDecoded = Uri.decodeFull(processedToken);
        processedToken = urlDecoded;
      } catch (e) {
        // No URL decoding needed
      }

      try {
        final jsonData = jsonDecode(processedToken);
        currentUser = User.fromJson(jsonData);

        await TokenStorage.saveToken(tokenData);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MyApp()),
          );
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Invalid token format received';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing login token';
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
              _controller.reload();
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
          WebViewWidget(controller: _controller),
          if (_isLoading)
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