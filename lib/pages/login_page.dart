// Dart imports:
import 'dart:async';
import 'dart:ui';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:cloudflare_turnstile/cloudflare_turnstile.dart';

// Project imports:
import '../models/current_user_state.dart';
import '../providers/theme_provider.dart';
import '../services/chat_services.dart';
import '../theme.dart';
import '../widgets/app_toast.dart';
import 'chat_home_page.dart';

/// Root app wrapper for the login experience
class LoginApp extends StatelessWidget {
  const LoginApp({super.key, this.autoLoggedOut = false});

  final bool autoLoggedOut;

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      themeService: globalThemeService,
      child: MaterialApp(
        title: 'LPU Live - Login',
        theme: lpuTheme,
        darkTheme: lpuDarkTheme,
        themeMode: ThemeMode.system, // use system default for login
        home: LoginScreen(autoLoggedOut: autoLoggedOut),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Unified, responsive login screen with password + Turnstile
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.autoLoggedOut = false});

  final bool autoLoggedOut;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Form state
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool _obscurePassword = true;
  bool _usernameHasError = false;
  bool _passwordHasError = false;
  bool _isSubmitting = false;
  String? _formError;

  // Turnstile
  final TurnstileController _turnstileController = TurnstileController();
  String? _turnstileToken;

  // Misc
  bool _hasShownLogoutMessage = false;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onCredentialsChanged);
    _passwordController.addListener(_onCredentialsChanged);
    _usernameFocus.addListener(() => mounted ? setState(() {}) : null);
    _passwordFocus.addListener(() => mounted ? setState(() {}) : null);
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

  void _onCredentialsChanged() {
    if (!mounted) return;
    setState(() {});
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
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _turnstileController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _usernameHasError = false;
      _passwordHasError = false;
    });

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _formError = 'Please enter both username and password';
        _usernameHasError = username.isEmpty;
        _passwordHasError = password.isEmpty;
      });
      if (username.isEmpty) {
        _usernameFocus.requestFocus();
      } else {
        _passwordFocus.requestFocus();
      }
      return;
    }
    if (_turnstileToken == null || _turnstileToken!.isEmpty) {
      setState(() {
        _formError = 'Please complete the verification';
      });
      return;
    }


    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
      _formError = null;
    });

    try {
      final api = ChatApiService();
      final user = await api.authenticateWithCredentials(
        username: username,
        password: password,
        turnstileToken: _turnstileToken!,
      );
      setCurrentUser(user);
      await TokenStorage.saveCurrentUser();
      TextInput.finishAutofillContext();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MyApp(),
          ),
        );
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Invalid CAPTCHA')) {
        setState(() {
          _formError = 'Invalid verification. Please try again.';
          _turnstileToken = null;
        });
        try {
          await _turnstileController.refreshToken();
        } catch (_) {}
      } else if (msg.contains('Invalid User')) {
        setState(() {
          _formError = 'No account found for that user ID.';
          _usernameHasError = true;
        });
        _usernameFocus.requestFocus();
      } else if (msg.contains('Invalid Password')) {
        setState(() {
          _formError = 'Incorrect password. Please try again.';
          _passwordHasError = true;
        });
        _passwordController.clear();
        _passwordFocus.requestFocus();
      } else {
        setState(() {
          _formError = msg.replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        title: null,
        actions: const [], // remove theme toggle
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // Background gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            scheme.surface,
                            scheme.surfaceContainerHighest,
                          ]
                        : [
                            scheme.primaryContainer,
                            scheme.surface,
                          ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  final card = _buildLoginCard(context, scheme);
                  final double targetMax = isWide ? 560.0 : 640.0;
                  final double usableWidth = constraints.maxWidth - 48; // account for horizontal padding
                  final double clampedWidth = usableWidth <= 0
                      ? 0.0
                      : (usableWidth > targetMax ? targetMax : usableWidth);

                  // Center strongly, accounting for safe areas
                  final media = MediaQuery.of(context);
                  final double verticalSafe = media.padding.top + media.padding.bottom;
                  final double minHeight = (constraints.maxHeight - verticalSafe - 48).clamp(0.0, double.infinity);

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: minHeight),
                            child: Center(
                              child: SizedBox(
                                width: clampedWidth,
                                child: card,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context, ColorScheme scheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          // Blur layer
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: const SizedBox.shrink(),
          ),
          // Glass container
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.white.withOpacity(0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.25)
                      : Colors.black.withOpacity(0.15),
                  blurRadius: isDark ? 24 : 28,
                  spreadRadius: isDark ? 2 : 4,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo + Title inside the glass card
                  Align(
                    alignment: Alignment.center,
                    child: Image.asset(
                      isDark ? 'assets/icon.png' : 'assets/icon-noglow.png',
                      height: 44,
                      width: 44,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Welcome back',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to continue your conversations',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.lock_outline, color: scheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sign in to your account',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AutofillGroup(
                    child: Column(
                      children: [
                        _AnimatedGlowField(
                          focusNode: _usernameFocus,
                          child: TextField(
                            controller: _usernameController,
                            focusNode: _usernameFocus,
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.text,
                            autofillHints: const [AutofillHints.username],
                            onSubmitted: (_) => _passwordFocus.requestFocus(),
                            style: TextStyle(
                              color: isDark ? null : const Color(0xFF444444),
                            ),
                            decoration: InputDecoration(
                              labelText: 'User ID',
                              floatingLabelBehavior: FloatingLabelBehavior.auto,
                              prefixIcon: Icon(
                                Icons.person_outline,
                                color: isDark ? null : const Color(0xFF444444),
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? scheme.surfaceContainerHighest.withOpacity(0.6)
                                  : Colors.white.withOpacity(0.7),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: scheme.outlineVariant),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: scheme.primary, width: 1.8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: scheme.error),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              labelStyle: TextStyle(color: isDark ? scheme.onSurfaceVariant : const Color(0xFF444444)),
                              floatingLabelStyle: TextStyle(color: scheme.primary),
                              errorText: _usernameHasError ? 'Check your user ID' : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _AnimatedGlowField(
                          focusNode: _passwordFocus,
                          child: TextField(
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            enableSuggestions: false,
                            autocorrect: false,
                            onSubmitted: (_) async {
                              await _submit();
                            },
                            style: TextStyle(
                              color: isDark ? null : const Color(0xFF444444),
                            ),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              floatingLabelBehavior: FloatingLabelBehavior.auto,
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: isDark ? null : const Color(0xFF444444),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: isDark ? null : const Color(0xFF444444),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? scheme.surfaceContainerHighest.withOpacity(0.6)
                                  : Colors.white.withOpacity(0.7),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: scheme.outlineVariant),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: scheme.primary, width: 1.8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: scheme.error),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              labelStyle: TextStyle(color: isDark ? scheme.onSurfaceVariant : const Color(0xFF444444)),
                              floatingLabelStyle: TextStyle(color: scheme.primary),
                              errorText: _passwordHasError ? 'Incorrect password' : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Captcha glass container (responsive)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.04)
                            : Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.12)
                              : Colors.white.withOpacity(0.3),
                        ),
                      ),
                      clipBehavior: Clip.hardEdge,
                      padding: const EdgeInsets.all(12),
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final double maxW = c.maxWidth;
                          return FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: maxW,
                              child: CloudflareTurnstile(
                                key: ValueKey('turnstile_${Theme.of(context).brightness}'),
                                siteKey: '0x4AAAAAABOGKSR1eAY3Gibs',
                                baseUrl: 'https://lpulive.lpu.in',
                                controller: _turnstileController,
                                options: TurnstileOptions(
                                  size: TurnstileSize.flexible,
                                  theme: Theme.of(context).brightness == Brightness.dark
                                      ? TurnstileTheme.dark
                                      : TurnstileTheme.light,
                                  language: 'en',
                                ),
                                onTokenReceived: (token) {
                                  setState(() {
                                    _turnstileToken = token;
                                    _formError = null;
                                  });
                                },
                                onTokenExpired: () {
                                  setState(() {
                                    _turnstileToken = null;
                                    _formError = 'Verification expired. Please verify again.';
                                  });
                                },
                                onError: (err) {
                                  setState(() {
                                    _formError = 'Verification failed: $err';
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _formError == null
                        ? const SizedBox.shrink()
                        : Container(
                            key: const ValueKey('error'),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.error_outline, color: scheme.error, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _formError!,
                                    style: TextStyle(color: scheme.onErrorContainer),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  _AnimatedPress(
                    enabled: !(_isSubmitting ||
                        _turnstileToken == null ||
                        _usernameController.text.trim().isEmpty ||
                        _passwordController.text.trim().isEmpty),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_isSubmitting || _turnstileToken == null ||
                                _usernameController.text.trim().isEmpty ||
                                _passwordController.text.trim().isEmpty)
                            ? null
                            : () async {
                                await _submit();
                              },
                        icon: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.login),
                        label: const Text('Login'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ).merge(
                          ButtonStyle(
                            overlayColor: MaterialStateProperty.resolveWith((states) {
                              if (states.contains(MaterialState.hovered) || states.contains(MaterialState.pressed)) {
                                return scheme.primary.withOpacity(0.1);
                              }
                              return null;
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Footer inside the card
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '© ${DateTime.now().year} LPU Live  •  Privacy  •  Terms',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
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

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Welcome back',
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in to continue your conversations',
            style: textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LoginFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '© ${DateTime.now().year} LPU Live',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {},
                  child: const Text('Privacy'),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Terms'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated glow wrapper for input fields
class _AnimatedGlowField extends StatelessWidget {
  const _AnimatedGlowField({
    required this.child,
    required this.focusNode,
  });

  final Widget child;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFocused = focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: scheme.primary.withOpacity(0.3),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

/// Press animation wrapper for buttons (ripple/scale)
class _AnimatedPress extends StatefulWidget {
  const _AnimatedPress({
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<_AnimatedPress> createState() => _AnimatedPressState();
}

class _AnimatedPressState extends State<_AnimatedPress> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 180),
      lowerBound: 0.0,
      upperBound: 0.06,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails d) {
    if (!widget.enabled) return;
    _controller.forward();
  }

  void _onTapUp(TapUpDetails d) {
    if (!widget.enabled) return;
    _controller.reverse();
  }

  void _onTapCancel() {
    if (!widget.enabled) return;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: Transform.scale(
              scale: 1.0 + (1.0 - _scale.value),
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
