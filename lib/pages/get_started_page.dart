import 'package:flutter/material.dart';
import 'token_input_page.dart';

class GetStartedPage extends StatelessWidget {
  const GetStartedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmall = size.height < 700;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D0D0D), Color(0xFF1A1A1A)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, isSmall ? 12 : 20, 20, 20),
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF101215), Color(0xFF0B0C0E)],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 20,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.fromLTRB(
                          24,
                          isSmall ? 20 : 28,
                          24,
                          24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Top Illustration
                            SizedBox(
                              height: isSmall ? 160 : 220,
                              child: Center(
                                child: Image.asset(
                                  'assets/student_chat.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Welcome to LPU LIVE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _Bullet(
                              text: 'Connect with your university groups',
                            ),
                            const SizedBox(height: 10),
                            _Bullet(text: 'Chat with your Classmates'),
                            const SizedBox(height: 10),
                            _Bullet(
                              text: 'Stay up-to-date with campus activities',
                            ),
                            const Spacer(),
                            SizedBox(
                              height: 58,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    PageRouteBuilder(
                                      transitionDuration: const Duration(
                                        milliseconds: 380,
                                      ),
                                      pageBuilder: (_, __, ___) =>
                                          const UnifiedLoginScreen(),
                                      transitionsBuilder:
                                          (_, animation, __, child) =>
                                              FadeTransition(
                                                opacity: animation,
                                                child: child,
                                              ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF36F21),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: const Text(
                                  'GET STARTED',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(width: 4),
        const Text('-', style: TextStyle(color: Colors.white70, fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
