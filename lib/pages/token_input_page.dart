// Dart imports:
import 'dart:async';

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
class TokenInputApp extends StatelessWidget {
  const TokenInputApp({super.key, this.autoLoggedOut = false});

  final bool autoLoggedOut;

  @override
  Widget build(BuildContext context) {
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

/// Unified, responsive login screen with password + Turnstile
class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({super.key, this.autoLoggedOut = false});

  final bool autoLoggedOut;

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> {
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
  Timer? _captchaValidityTimer;

  // Misc
  bool _hasShownLogoutMessage = false;

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

    // Periodically verify Turnstile token validity (every 15s)
    _captchaValidityTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!mounted) return;
      if (_turnstileToken == null) return; // nothing to check
      if (_isSubmitting) return; // avoid checks during submission
      try {
        final expired = await _turnstileController.isExpired();
        if (expired) {
          if (!mounted) return;
          setState(() {
            _formError = 'Verification expired. Please verify again.';
            _turnstileToken = null;
          });
          try {
            await _turnstileController.refreshToken();
          } catch (_) {}
        }
      } catch (_) {}
    });
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
    _captchaValidityTimer?.cancel();
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

    // Ensure token not expired
    try {
      final expired = await _turnstileController.isExpired();
      if (expired) {
        setState(() {
          _formError = 'Verification expired. Please verify again.';
          _turnstileToken = null;
        });
        await _turnstileController.refreshToken();
        return;
      }
    } catch (_) {}

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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        title: Row(
          children: [
            Image.asset(
              'assets/icon-noglow.png',
              height: 28,
              width: 28,
            ),
            const SizedBox(width: 10),
            const Text('LPU Live'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            onPressed: () {
              final next = globalThemeService.themeMode == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark;
              globalThemeService.setThemeMode(next);
            },
            icon: Icon(
              globalThemeService.themeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // Background gradient + subtle pattern overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary.withValues(alpha: 0.08),
                      scheme.surfaceContainerHighest,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),

            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  final card = _buildLoginCard(context, scheme);

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: isWide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Left: Hero/branding panel
                                  Expanded(
                                    child: _HeroPanel(scheme: scheme),
                                  ),
                                  const SizedBox(width: 24),
                                  // Right: Login card
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 520),
                                    child: card,
                                  ),
                                ],
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  children: [
                                    _HeroPanel(scheme: scheme),
                                    const SizedBox(height: 16),
                                    card,
                                  ],
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
      bottomNavigationBar: _LoginFooter(),
    );
  }

  Widget _buildLoginCard(BuildContext context, ColorScheme scheme) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 16),
            AutofillGroup(
              child: Column(
                children: [
                  TextField(
                    controller: _usernameController,
                    focusNode: _usernameFocus,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.text,
                    autofillHints: const [AutofillHints.username],
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                    decoration: InputDecoration(
                      labelText: 'User ID',
                      hintText: 'e.g. 12345678',
                      prefixIcon: const Icon(Icons.person_outline),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: scheme.primary),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: scheme.error),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorText: _usernameHasError ? 'Check your user ID' : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
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
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                      ),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: scheme.primary),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: scheme.error),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorText: _passwordHasError ? 'Incorrect password' : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: CloudflareTurnstile(
                siteKey: '0x4AAAAAABOGKSR1eAY3Gibs',
                baseUrl: 'https://lpulive.lpu.in',
                controller: _turnstileController,
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
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _formError == null
                  ? const SizedBox.shrink()
                  : Container(
                      key: const ValueKey('error'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting
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
                label: Text(_isSubmitting ? 'Signing in…' : 'Sign in'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.18),
            scheme.primary.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/icon-noglow.png',
                    height: 48,
                    width: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'LPU Live',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome back',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in with your university credentials',
            style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
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
