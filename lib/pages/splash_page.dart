// Dart imports:
import 'dart:convert';

// Flutter imports:
import 'package:flutter/material.dart';

// Project imports:
import '../models/current_user_state.dart';
import '../models/user_models.dart';
import '../services/chat_services.dart';
import '../widgets/notification_permission_dialog.dart';
import 'chat_home_page.dart';
import 'login_page.dart';

// removed extra spinner

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () async {
      // Request notification permission first
      await _requestNotificationPermissionIfNeeded();

      final savedToken = await TokenStorage.getToken();
      if (!mounted) return;
      if (savedToken == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const LoginScreen(autoLoggedOut: false),
          ),
        );
        return;
      }

      // Try to decode stored token into currentUser
      bool decoded = false;
      debugPrint('🔍 [SplashPage] Attempting to decode saved token...');
      try {
        final Map<String, dynamic> jsonData = jsonDecode(savedToken);
        setCurrentUser(User.fromJson(jsonData));
        decoded = true;
        debugPrint('✅ [SplashPage] Token decoded successfully (JSON format)');
      } catch (e) {
        debugPrint('⚠️ [SplashPage] JSON decode failed: $e, trying base64...');
        try {
          final decodedBytes = base64Decode(savedToken);
          final decodedString = utf8.decode(decodedBytes);
          final urlDecodedString = Uri.decodeFull(decodedString);
          final Map<String, dynamic> jsonData = jsonDecode(urlDecodedString);
          setCurrentUser(User.fromJson(jsonData));
          decoded = true;
          debugPrint(
            '✅ [SplashPage] Token decoded successfully (Base64 format)',
          );
        } catch (e2) {
          debugPrint('❌ [SplashPage] Base64 decode also failed: $e2');
          decoded = false;
        }
      }

      if (!decoded || currentUser?.chatToken.isEmpty != false) {
        await TokenStorage.clearToken();
        setCurrentUser(null);
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const LoginScreen(autoLoggedOut: true),
            ),
          );
        }
        return;
      }

      // Server validation using authorize endpoint
      debugPrint(
        '🔍 [SplashPage] Attempting to authorize user with token: ${currentUser!.chatToken}',
      );
      try {
        final api = ChatApiService();
        final updatedUser = await api
            .authorizeUser(currentUser!.chatToken)
            .timeout(const Duration(seconds: 6));

        debugPrint(
          '✅ [SplashPage] Authorization successful, updating user data...',
        );
        // Update currentUser with new token and data from server
        setCurrentUser(updatedUser);
        await TokenStorage.saveCurrentUser();

        if (!mounted) return;
        debugPrint('🚀 [SplashPage] Navigating to ChatHomePage...');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChatHomePage()),
        );
      } catch (e) {
        // Only clear token for unauthorized access, not for network errors
        if (e is UnauthorizedException) {
          debugPrint(
            '❌ [SplashPage] User unauthorized, clearing token and logging out...',
          );
          await TokenStorage.clearToken();
          setCurrentUser(null);
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const LoginScreen(autoLoggedOut: true),
            ),
          );
        } else if (e is NetworkException) {
          debugPrint(
            '🌐 [SplashPage] Network error during authorization, keeping token and going to app...',
          );
          // For network errors, keep the token and go to app (user can retry later)
          if (!mounted) return;
          debugPrint(
            '🚀 [SplashPage] Navigating to ChatHomePage (network error)...',
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ChatHomePage()),
          );
        } else {
          debugPrint(
            '⚠️ [SplashPage] Other error during authorization: $e, keeping token and going to app...',
          );
          // For other errors, keep the token and go to app (assume token is still valid)
          if (!mounted) return;
          debugPrint(
            '🚀 [SplashPage] Navigating to ChatHomePage (other error)...',
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ChatHomePage()),
          );
        }
      }
    });
  }

  /// Request notification permission if needed
  Future<void> _requestNotificationPermissionIfNeeded() async {
    try {
      if (!mounted) return;

      // Show the permission dialog
      await NotificationPermissionDialogHelper.showPermissionDialogIfNeeded(context);
    } catch (e) {
      debugPrint('❌ [SplashPage] Error requesting notification permission: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: color.surface,
      body: Stack(
        children: [
          // Static radial background
          Positioned.fill(
            child: CustomPaint(
              painter: _RadialGlowPainter(
                color.primary.withValues(alpha: 0.18),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/icon-noglow.png',
                  width: 92,
                  height: 92,
                ),
                const SizedBox(height: 20),
                Text(
                  'LPU Live',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// removed animated chat bubbles in favor of static app icon

class _RadialGlowPainter extends CustomPainter {
  final Color color;
  _RadialGlowPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.6;
    final gradient = RadialGradient(
      colors: [color, Colors.transparent],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    final paint = Paint()..shader = gradient;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _RadialGlowPainter oldDelegate) =>
      oldDelegate.color != color;
}

class MathUtils {
  static double sin(double x) => MathUtils._tableSin(x);
  // Simple sine approximation using dart:math would require import; keep minimal here
  static double _tableSin(double x) {
    // Wrap to 0..2pi
    const double pi2 = 6.283185307179586;
    x = x % pi2;
    // Use Taylor series (good enough for small animation)
    final x2 = x * x;
    final x3 = x2 * x;
    final x5 = x3 * x2;
    final x7 = x5 * x2;
    return x - (x3 / 6) + (x5 / 120) - (x7 / 5040);
  }
}
