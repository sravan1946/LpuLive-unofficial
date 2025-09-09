import 'package:flutter/material.dart';

enum ToastType { info, success, warning, error }

void showAppToast(
  BuildContext context,
  String message, {
  ToastType type = ToastType.info,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Overlay.of(context);

  final theme = Theme.of(context);
  final scheme = theme.colorScheme;

  Color background;
  Color foreground;
  IconData icon;

  switch (type) {
    case ToastType.success:
      background = Colors.green;
      foreground = Colors.white;
      icon = Icons.check_circle_rounded;
      break;
    case ToastType.warning:
      background = scheme.primary; // brand orange in theme
      foreground = scheme.onPrimary;
      icon = Icons.warning_amber_rounded;
      break;
    case ToastType.error:
      background = Colors.redAccent;
      foreground = Colors.white;
      icon = Icons.error_outline_rounded;
      break;
    case ToastType.info:
      background = scheme.inverseSurface;
      foreground = scheme.onInverseSurface;
      icon = Icons.info_outline_rounded;
      break;
  }

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _ToastOverlay(
      background: background,
      foreground: foreground,
      icon: icon,
      message: message,
      duration: duration,
      onDismissed: () => entry.remove(),
    ),
  );

  overlay.insert(entry);
}

class _ToastOverlay extends StatefulWidget {
  final Color background;
  final Color foreground;
  final IconData icon;
  final String message;
  final Duration duration;
  final VoidCallback onDismissed;

  const _ToastOverlay({
    required this.background,
    required this.foreground,
    required this.icon,
    required this.message,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, -0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _controller.forward();
    Future.delayed(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
      if (mounted) widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topPadding = media.padding.top + 12;
    return IgnorePointer(
      ignoring: true,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: SlideTransition(
              position: _offset,
              child: FadeTransition(
                opacity: _opacity,
                child: _ToastContent(
                  background: widget.background,
                  foreground: widget.foreground,
                  icon: widget.icon,
                  message: widget.message,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastContent extends StatelessWidget {
  final Color background;
  final Color foreground;
  final IconData icon;
  final String message;

  const _ToastContent({
    required this.background,
    required this.foreground,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: foreground, size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
