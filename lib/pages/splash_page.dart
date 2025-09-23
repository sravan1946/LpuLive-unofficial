// Dart imports:
import 'dart:convert';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_animate/flutter_animate.dart';

// Project imports:
import '../models/current_user_state.dart';
import '../models/user_models.dart';
import '../services/chat_services.dart';
import 'chat_home_page.dart';
import 'login_page.dart';

// removed extra spinner

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _scaleIn = Tween<double>(
      begin: 0.98,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.delayed(const Duration(seconds: 4), () async {
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: color.surface,
      body: Stack(
        children: [
          // Soft animated radial background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                return CustomPaint(
                  painter: _RadialGlowPainter(
                    color.primary.withValues(alpha: 0.12 + 0.06 * t),
                  ),
                );
              },
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: ScaleTransition(
                scale: _scaleIn,
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
                        )
                        .animate()
                        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                        .moveY(
                          begin: 8,
                          end: 0,
                          duration: 400.ms,
                          curve: Curves.easeOut,
                        ),
                  ],
                ),
              ),
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
