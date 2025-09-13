import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
// removed extra spinner
import 'chat_home_page.dart';
import 'token_input_page.dart';
import '../services/chat_services.dart';
import 'dart:convert';
import '../models/user_models.dart';

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
            builder: (_) => const UnifiedLoginScreen(autoLoggedOut: false),
          ),
        );
        return;
      }

      // Try to decode stored token into currentUser
      bool decoded = false;
      try {
        final Map<String, dynamic> jsonData = jsonDecode(savedToken);
        currentUser = User.fromJson(jsonData);
        decoded = true;
      } catch (_) {
        try {
          final decodedBytes = base64Decode(savedToken);
          final decodedString = utf8.decode(decodedBytes);
          final urlDecodedString = Uri.decodeFull(decodedString);
          final Map<String, dynamic> jsonData = jsonDecode(urlDecodedString);
          currentUser = User.fromJson(jsonData);
          decoded = true;
        } catch (_) {
          decoded = false;
        }
      }

      if (!decoded || currentUser?.chatToken.isEmpty != false) {
        await TokenStorage.clearToken();
        currentUser = null;
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const UnifiedLoginScreen(autoLoggedOut: true),
            ),
          );
        }
        return;
      }

      // Lightweight server validation
      try {
        final api = ChatApiService();
        await api
            .fetchContacts(currentUser!.chatToken)
            .timeout(const Duration(seconds: 6));
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChatHomePage()),
        );
      } catch (_) {
        await TokenStorage.clearToken();
        currentUser = null;
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const UnifiedLoginScreen(autoLoggedOut: true),
          ),
        );
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
                    Image.asset('assets/icon-noglow.png', width: 92, height: 92),
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
