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
   late final WebViewController _controller;
   bool _isLoading = true;
   String? _errorMessage;
   bool _isMonitoring = false;
   int _checkAttempts = 0;
   static const int _maxCheckAttempts = 30; // 30 seconds timeout

  @override
  void dispose() {
     developer.log('🗑️ WebViewLoginScreen disposed', name: 'WebViewLogin');
     super.dispose();
   }

  Future<void> _periodicUrlCheck() async {
     if (!mounted) return;

     try {
       // Get current URL
       final currentUrl = await _controller.currentUrl();
       if (currentUrl != null) {
         bool isChatUrl = currentUrl.contains('/chat') || currentUrl.contains('chat') ||
                         currentUrl.contains('Chat') || currentUrl.contains('CHAT');

         if (isChatUrl && !_isMonitoring) {
           developer.log('🎯 Periodic check: Detected chat URL! Starting monitoring...', name: 'WebViewLogin');
           _isMonitoring = true;
           _checkAttempts = 0;
           await _checkForAuthData();
         }
       }
     } catch (e) {
       developer.log('❌ Error in periodic URL check: $e', name: 'WebViewLogin');
     }

     // Schedule next check if still monitoring or if we might be on a chat page
     if (mounted && (_isMonitoring || _checkAttempts < _maxCheckAttempts)) {
       Future.delayed(const Duration(seconds: 3), _periodicUrlCheck);
     }
   }

   Future<void> _testJavaScript() async {
     if (_controller == null) {
       developer.log('❌ Cannot test JavaScript: WebViewController is null', name: 'WebViewLogin');
       return;
     }

     try {
       developer.log('🧪 Testing JavaScript execution...', name: 'WebViewLogin');
       const String testScript = '''
         (function() {
           try {
             console.log('🧪 JavaScript test: Hello from webview!');
             return 'JS_WORKING';
           } catch (e) {
             console.log('🧪 JavaScript test error:', e);
             return 'JS_ERROR:' + e.toString();
           }
         })();
       ''';

       final result = await _controller.runJavaScriptReturningResult(testScript);
       developer.log('🧪 JavaScript test result: $result', name: 'WebViewLogin');

       if (result.toString().contains('JS_WORKING')) {
         developer.log('✅ JavaScript is working properly', name: 'WebViewLogin');
       } else if (result.toString().contains('JS_ERROR')) {
         developer.log('❌ JavaScript execution error: $result', name: 'WebViewLogin');
       } else {
         developer.log('❓ Unexpected JavaScript test result: $result', name: 'WebViewLogin');
       }
     } catch (e) {
       developer.log('💥 JavaScript test error: $e', name: 'WebViewLogin');
       setState(() {
         _errorMessage = 'JavaScript test failed: $e';
       });
     }
   }

   Future<void> _clearWebViewLocalStorage() async {
     if (_controller == null) {
       developer.log('❌ Cannot clear localStorage: WebViewController is null', name: 'WebViewLogin');
       return;
     }

     try {
       developer.log('🗑️ Clearing webview localStorage...', name: 'WebViewLogin');

       // First test if JavaScript is working
       await _testJavaScript();

       const String clearScript = '''
         (function() {
           try {
             console.log('🗑️ JavaScript: Clearing localStorage');
             const beforeClear = localStorage.length;
             localStorage.clear();
             const afterClear = localStorage.length;
             console.log('✅ JavaScript: localStorage cleared - before:', beforeClear, 'after:', afterClear);
             return 'CLEARED_' + beforeClear + '_to_' + afterClear;
           } catch (e) {
             console.log('❌ JavaScript: Error clearing localStorage:', e);
             return 'ERROR:' + e.toString();
           }
         })();
       ''';

       final result = await _controller.runJavaScriptReturningResult(clearScript);
       developer.log('🗑️ Clear localStorage result: $result', name: 'WebViewLogin');

       if (result.toString().contains('CLEARED')) {
         developer.log('✅ Webview localStorage cleared successfully', name: 'WebViewLogin');
       } else if (result.toString().contains('ERROR')) {
         developer.log('❌ JavaScript error clearing localStorage: $result', name: 'WebViewLogin');
         setState(() {
           _errorMessage = 'Failed to clear webview localStorage: ${result.toString().substring(6)}';
         });
       } else {
         developer.log('❓ Unexpected clear result: $result', name: 'WebViewLogin');
       }
     } catch (e) {
       developer.log('💥 Error clearing webview localStorage: $e', name: 'WebViewLogin');
       setState(() {
         _errorMessage = 'Error clearing webview localStorage: $e';
       });
     }
   }

    @override
   void initState() {
     super.initState();
     developer.log('🚀 WebView Login Screen initialized', name: 'WebViewLogin');

     try {
       _controller = WebViewController()
         ..setJavaScriptMode(JavaScriptMode.unrestricted)
         ..setNavigationDelegate(
         NavigationDelegate(
           onPageStarted: (String url) {
             developer.log('🌐 Page started loading: $url', name: 'WebViewLogin');
             setState(() {
               _isLoading = true;
               _errorMessage = null;
             });
           },
           onPageFinished: (String url) async {
             developer.log('✅ Page finished loading: $url', name: 'WebViewLogin');
             setState(() {
               _isLoading = false;
             });

             // Wait a bit for the page to be fully ready
             await Future.delayed(const Duration(milliseconds: 500));
             developer.log('⏳ Page ready delay completed', name: 'WebViewLogin');

             // Clear localStorage in the webview when page loads
             await _clearWebViewLocalStorage();

             // Check if we've been redirected to /chat (more flexible detection)
             bool isChatUrl = url.contains('/chat') || url.contains('chat') || url.endsWith('/chat') ||
                             url.contains('Chat') || url.contains('CHAT');
             developer.log('🔍 URL analysis: "$url"', name: 'WebViewLogin');
             developer.log('🔍 URL contains /chat: ${url.contains("/chat")}', name: 'WebViewLogin');
             developer.log('🔍 URL contains chat: ${url.contains("chat")}', name: 'WebViewLogin');
             developer.log('🔍 URL ends with /chat: ${url.endsWith("/chat")}', name: 'WebViewLogin');
             developer.log('🔍 isChatUrl: $isChatUrl, currently monitoring: $_isMonitoring', name: 'WebViewLogin');

             if (isChatUrl) {
               if (!_isMonitoring) {
                 developer.log('🎯 Detected chat URL! Starting AuthData monitoring...', name: 'WebViewLogin');
                 _isMonitoring = true;
                 _checkAttempts = 0; // Reset attempts counter
                 // Wait a bit more before starting monitoring
                 await Future.delayed(const Duration(milliseconds: 1000));
                 developer.log('🚀 Starting continuous AuthData monitoring...', name: 'WebViewLogin');
                 await _checkForAuthData();
               } else {
                 developer.log('🔄 Already monitoring on chat URL, continuing...', name: 'WebViewLogin');
               }
             } else {
               if (_isMonitoring) {
                 developer.log('❌ Left chat URL, stopping monitoring', name: 'WebViewLogin');
                 _isMonitoring = false;
                 _checkAttempts = 0; // Reset attempts counter
               } else {
                 developer.log('📄 Regular page loaded, not monitoring', name: 'WebViewLogin');
               }
             }
           },
           onWebResourceError: (WebResourceError error) {
             developer.log('❌ Web resource error: ${error.description}', name: 'WebViewLogin');
             setState(() {
               _isLoading = false;
               _errorMessage = 'Failed to load page: ${error.description}';
             });
           },
           onNavigationRequest: (NavigationRequest request) {
             developer.log('🧭 Navigation request: ${request.url}', name: 'WebViewLogin');
             // Allow navigation to lpulive.lpu.in and its subdomains
             if (request.url.startsWith('https://lpulive.lpu.in')) {
               developer.log('✅ Allowing navigation to: ${request.url}', name: 'WebViewLogin');
               return NavigationDecision.navigate;
             }
             developer.log('🚫 Blocking navigation to: ${request.url}', name: 'WebViewLogin');
             return NavigationDecision.prevent;
           },
           onUrlChange: (UrlChange change) {
             developer.log('🔗 URL changed to: ${change.url}', name: 'WebViewLogin');
           },
         ),
       )
       ..loadRequest(Uri.parse('https://lpulive.lpu.in'));
     developer.log('🎮 WebViewController created successfully', name: 'WebViewLogin');
     developer.log('📱 Loading initial URL: https://lpulive.lpu.in', name: 'WebViewLogin');

     // Start periodic URL checking as backup
     Future.delayed(const Duration(seconds: 2), _periodicUrlCheck);
     } catch (e) {
       developer.log('💥 Error creating WebViewController: $e', name: 'WebViewLogin');
       setState(() {
         _errorMessage = 'Failed to initialize webview: $e';
       });
       return;
     }
    }

    Future<void> _checkForAuthData() async {
      if (_controller == null) {
        developer.log('❌ Cannot check AuthData: WebViewController is null', name: 'WebViewLogin');
        return;
      }

      developer.log('🔍 Checking for AuthData (attempt $_checkAttempts/$_maxCheckAttempts)', name: 'WebViewLogin');

      if (_checkAttempts >= _maxCheckAttempts) {
        developer.log('⏰ Timeout reached! Stopping AuthData monitoring', name: 'WebViewLogin');
        setState(() {
          _isMonitoring = false;
          _errorMessage = 'Login timeout: AuthData not found within 30 seconds. Please try again.';
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
       developer.log('💻 Executing JavaScript to get AuthData...', name: 'WebViewLogin');
       final result = await _controller.runJavaScriptReturningResult(script);
       final authData = result.toString().replaceAll('"', '');
       developer.log('📊 JavaScript result: "$result"', name: 'WebViewLogin');
       developer.log('🔧 Processed AuthData: "$authData"', name: 'WebViewLogin');

       if (authData.startsWith('SUCCESS:')) {
         final actualData = authData.substring(8); // Remove 'SUCCESS:' prefix
         developer.log('🎉 AuthData found! Length: ${actualData.length}', name: 'WebViewLogin');
         await _processAuthData(actualData);
       } else if (authData.startsWith('ERROR:')) {
         developer.log('💥 JavaScript error: $authData', name: 'WebViewLogin');
         setState(() {
           _errorMessage = 'JavaScript error: ${authData.substring(6)}';
           _isMonitoring = false;
         });
       } else if (authData.startsWith('NO_LOCALSTORAGE')) {
         developer.log('❌ localStorage not available in webview', name: 'WebViewLogin');
         setState(() {
           _errorMessage = 'localStorage not available in webview';
           _isMonitoring = false;
         });
       } else if (authData.startsWith('NO_AUTH_DATA_KEYS:')) {
         final keys = authData.substring(18); // Remove 'NO_AUTH_DATA_KEYS:' prefix
         developer.log('❌ AuthData not found, available keys: $keys', name: 'WebViewLogin');
         developer.log('🔄 Will check again in 1 second (monitoring: $_isMonitoring)', name: 'WebViewLogin');
         // AuthData not found yet, check again in 1 second
         Future.delayed(const Duration(seconds: 1), () {
           if (mounted && _isMonitoring) {
             developer.log('🔄 Continuing monitoring - checking again...', name: 'WebViewLogin');
             _checkForAuthData();
           } else {
             developer.log('⏹️ Monitoring stopped, not checking again', name: 'WebViewLogin');
           }
         });
       } else {
         developer.log('❓ Unexpected result: "$authData", will check again in 1 second', name: 'WebViewLogin');
         developer.log('🔄 Will check again in 1 second (monitoring: $_isMonitoring)', name: 'WebViewLogin');
         // AuthData not found yet, check again in 1 second
         Future.delayed(const Duration(seconds: 1), () {
           if (mounted && _isMonitoring) {
             developer.log('🔄 Continuing monitoring - checking again...', name: 'WebViewLogin');
             _checkForAuthData();
           } else {
             developer.log('⏹️ Monitoring stopped, not checking again', name: 'WebViewLogin');
           }
         });
       }
     } catch (e) {
       developer.log('💥 Error executing JavaScript: $e', name: 'WebViewLogin');
       setState(() {
         _errorMessage = 'Error accessing localStorage: ${e.toString()}';
         _isMonitoring = false;
       });
     }
   }

   Future<void> _processAuthData(String authData) async {
     developer.log('🔄 Processing AuthData...', name: 'WebViewLogin');
     try {
       // Process the AuthData (assuming it's in the same format as before)
       await _processWebViewToken(authData);

       if (currentUser != null && mounted) {
         developer.log('✅ User created successfully! Navigating to main app...', name: 'WebViewLogin');
         developer.log('👤 User: ${currentUser!.name}, Token: ${currentUser!.chatToken.substring(0, 20)}...', name: 'WebViewLogin');
         // Navigate to main app
         Navigator.of(context).pushReplacement(
           MaterialPageRoute(builder: (context) => const MyApp()),
         );
       } else {
         developer.log('❌ Failed to create user from AuthData', name: 'WebViewLogin');
         setState(() {
           _errorMessage = 'Failed to process authentication data: Invalid format';
           _isMonitoring = false;
         });
       }
     } catch (e) {
       developer.log('💥 Error processing AuthData: $e', name: 'WebViewLogin');
       setState(() {
         _errorMessage = 'Error processing authentication data: ${e.toString()}';
         _isMonitoring = false;
       });
     }
   }



   Future<void> _processWebViewToken(String tokenData) async {
     developer.log('🔧 Processing token data...', name: 'WebViewLogin');
     developer.log('📝 Raw token length: ${tokenData.length}', name: 'WebViewLogin');
     developer.log('📝 Raw token preview: ${tokenData.substring(0, min(50, tokenData.length))}...', name: 'WebViewLogin');

     try {
       String processedToken = tokenData;

       // Try to decode if it's base64
       try {
         developer.log('🔄 Attempting base64 decode...', name: 'WebViewLogin');
         final decodedBytes = base64Decode(tokenData);
         processedToken = utf8.decode(decodedBytes);
         developer.log('✅ Base64 decode successful', name: 'WebViewLogin');
       } catch (e) {
         developer.log('⚠️ Base64 decode failed, using as-is: $e', name: 'WebViewLogin');
         // Token might not be base64 encoded, use as is
       }

       // Try URL decoding
       try {
         developer.log('🔄 Attempting URL decode...', name: 'WebViewLogin');
         final urlDecoded = Uri.decodeFull(processedToken);
         processedToken = urlDecoded;
         developer.log('✅ URL decode successful', name: 'WebViewLogin');
       } catch (e) {
         developer.log('⚠️ URL decode failed, using as-is: $e', name: 'WebViewLogin');
         // No URL decoding needed
       }

       developer.log('📝 Processed token length: ${processedToken.length}', name: 'WebViewLogin');
       developer.log('📝 Processed token preview: ${processedToken.substring(0, min(50, processedToken.length))}...', name: 'WebViewLogin');

       // Try to parse as JSON
       try {
         developer.log('🔄 Attempting JSON parse...', name: 'WebViewLogin');
         final jsonData = jsonDecode(processedToken);
         currentUser = User.fromJson(jsonData);
         developer.log('✅ JSON parse successful! User created', name: 'WebViewLogin');

         // Save the original token data
         await TokenStorage.saveToken(tokenData);
         developer.log('💾 Token saved to storage', name: 'WebViewLogin');
       } catch (e) {
         developer.log('❌ JSON parse failed, trying raw token: $e', name: 'WebViewLogin');
         // If it's not JSON, it might be the raw token
         try {
           final jsonData = jsonDecode(tokenData);
           currentUser = User.fromJson(jsonData);
           await TokenStorage.saveToken(tokenData);
           developer.log('✅ Raw token JSON parse successful!', name: 'WebViewLogin');
         } catch (e2) {
           developer.log('💥 Both JSON parse attempts failed: $e2', name: 'WebViewLogin');
           setState(() {
             _errorMessage = 'Invalid token format received';
           });
           return;
         }
       }
     } catch (e) {
       developer.log('💥 Error processing token: $e', name: 'WebViewLogin');
       setState(() {
         _errorMessage = 'Error processing login token';
       });
     }
   }

  @override
  Widget build(BuildContext context) {
    developer.log('🔄 WebViewLoginScreen build called', name: 'WebViewLogin');
    return Scaffold(
        appBar: AppBar(
          title: const Text('LPU Live - Web Login'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                developer.log('🔄 Manual reload triggered', name: 'WebViewLogin');
                _controller.reload();
              },
              tooltip: 'Refresh',
            ),
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                developer.log('⬅️ Back to token input', name: 'WebViewLogin');
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
          Builder(
            builder: (context) {
              developer.log('🌐 WebViewWidget building with controller', name: 'WebViewLogin');
              return WebViewWidget(controller: _controller);
            },
          ),
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