import 'package:flutter/material.dart';
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

    Future.delayed(const Duration(milliseconds: 900), () async {
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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const UnifiedLoginScreen(autoLoggedOut: true),
          ),
        );
        return;
      }

      // Lightweight server validation
      try {
        final api = ChatApiService();
        await api.fetchContacts(currentUser!.chatToken).timeout(
              const Duration(seconds: 6),
            );
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
                    // Chat bubble made from shapes (no asset)
                    _AnimatedChatBubbles(controller: _controller),
                    const SizedBox(height: 20),
                    Text(
                      'LPU Live Chat',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connecting…',
                      style: TextStyle(color: color.onSurfaceVariant),
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

class _AnimatedChatBubbles extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedChatBubbles({required this.controller});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return SizedBox(
      width: 120,
      height: 84,
      child: Column(
        children: [
          // Main bubble
          Container(
            width: 88,
            height: 48,
            decoration: BoxDecoration(
              color: color.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  // Typing dots
                  final t = controller.value;
                  double dot(double phase) =>
                      1 + 0.2 * (MathUtils.sin((t + phase) * 2 * 3.1415));
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _dot(color.onPrimary, scale: dot(0.00)),
                      const SizedBox(width: 6),
                      _dot(color.onPrimary, scale: dot(0.20)),
                      const SizedBox(width: 6),
                      _dot(color.onPrimary, scale: dot(0.40)),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Tail bubble
          Align(
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: const Offset(22, 0),
              child: Container(
                width: 18,
                height: 14,
                decoration: BoxDecoration(
                  color: color.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color c, {double scale = 1}) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
    );
  }
}

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
