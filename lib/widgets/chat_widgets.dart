import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:async';
import '../models/user_models.dart';
import '../widgets/network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:photo_view/photo_view.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/app_toast.dart';

class SwipeToReplyMessage extends StatefulWidget {
  final ChatMessage message;
  final bool isReadOnly;
  final VoidCallback onReply;
  final VoidCallback onLongPress;
  final Widget child;

  const SwipeToReplyMessage({
    super.key,
    required this.message,
    required this.isReadOnly,
    required this.onReply,
    required this.onLongPress,
    required this.child,
  });

  @override
  State<SwipeToReplyMessage> createState() => _SwipeToReplyMessageState();
}

class _SwipeToReplyMessageState extends State<SwipeToReplyMessage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  
  double _dragOffset = 0.0;
  bool _isDragging = false;
  static const double _swipeThreshold = 100.0;
  static const double _maxSwipeDistance = 150.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    if (widget.isReadOnly) return;
    _isDragging = true;
    _animationController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging || widget.isReadOnly) return;
    
    setState(() {
      _dragOffset = (details.delta.dx + _dragOffset).clamp(0.0, _maxSwipeDistance);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging || widget.isReadOnly) return;
    
    _isDragging = false;
    
    if (_dragOffset > _swipeThreshold) {
      // Trigger reply
      HapticFeedback.lightImpact();
      widget.onReply();
      _resetAnimation();
    } else {
      // Snap back
      _resetAnimation();
    }
  }

  void _resetAnimation() {
    _animationController.forward().then((_) {
      setState(() {
        _dragOffset = 0.0;
      });
      _animationController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onLongPressStart: (details) {
        HapticFeedback.mediumImpact();
        widget.onLongPress();
      },
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Stack(
        children: [
          // Reply indicator background
          if (_dragOffset > 20)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: _dragOffset,
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(
                    Icons.reply,
                    color: scheme.primary,
                    size: 20,
                  ),
                ),
              ),
            ),
          // Main content
          AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_dragOffset, 0),
                child: Transform.scale(
                  scale: _isDragging ? 0.98 : 1.0,
                  child: widget.child,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ChatPatternPainter extends CustomPainter {
  final Color dotColor;
  final Color secondaryDotColor;
  final double spacing;
  final double radius;

  ChatPatternPainter({
    required this.dotColor,
    required this.secondaryDotColor,
    this.spacing = 24,
    this.radius = 1.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintPrimary = Paint()..color = dotColor;
    final paintSecondary = Paint()..color = secondaryDotColor;

    // Offset grid pattern of small dots
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        final isAlt =
            (((x / spacing).floor() + (y / spacing).floor()) % 2) == 0;
        canvas.drawCircle(
          Offset(x, y),
          radius,
          isAlt ? paintPrimary : paintSecondary,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant ChatPatternPainter oldDelegate) {
    return oldDelegate.dotColor != dotColor ||
        oldDelegate.secondaryDotColor != secondaryDotColor ||
        oldDelegate.spacing != spacing ||
        oldDelegate.radius != radius;
  }
}

class UnreadDivider extends StatelessWidget {
  const UnreadDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: scheme.primary.withValues(alpha: 0.3)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(48),
            ),
            child: Text(
              'Unread',
              style: TextStyle(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: scheme.primary.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }
}

class DateBanner extends StatelessWidget {
  final String label;
  const DateBanner({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: scheme.primary.withValues(alpha: 0.24)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(48),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: scheme.primary.withValues(alpha: 0.24)),
          ),
        ],
      ),
    );
  }
}

class MessageBody extends StatelessWidget {
  final ChatMessage message;
  final bool isOwn;
  final Function(String) onImageTap;
  final Function(BuildContext, ChatMessage)? onMessageOptions;

  const MessageBody({
    super.key,
    required this.message,
    required this.isOwn,
    required this.onImageTap,
    this.onMessageOptions,
  });

  bool _isImageUrl(String s) {
    final u = s.toLowerCase();
    return u.endsWith('.png') ||
        u.endsWith('.jpg') ||
        u.endsWith('.jpeg') ||
        u.endsWith('.gif') ||
        u.endsWith('.webp');
  }

  bool _isDocUrl(String s) {
    final u = s.toLowerCase();
    return u.endsWith('.pdf') ||
        u.endsWith('.doc') ||
        u.endsWith('.docx') ||
        u.endsWith('.ppt') ||
        u.endsWith('.pptx') ||
        u.endsWith('.xls') ||
        u.endsWith('.xlsx');
  }

  List<InlineSpan> _linkify(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    final regex = RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);
    final spans = <InlineSpan>[];
    int last = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: TextStyle(
            decoration: TextDecoration.underline,
            color: isOwn
                ? Theme.of(context).colorScheme.onPrimary
                : scheme.primary,
            fontWeight: FontWeight.w600,
          ),
          recognizer: (TapGestureRecognizer()..onTap = () => _openUrl(url)),
        ),
      );
      last = match.end;
    }
    if (last < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(last),
          style: TextStyle(
            color: isOwn
                ? Theme.of(context).colorScheme.onPrimary
                : (Theme.of(context).brightness == Brightness.light
                      ? Colors.black
                      : Theme.of(context).colorScheme.onSurface),
          ),
        ),
      );
    }
    return spans;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final text = message.message.trim();
    final scheme = Theme.of(context).colorScheme;

    // Prefer explicit media rendering when media is attached to the message
    if ((message.mediaUrl != null && message.mediaUrl!.isNotEmpty)) {
      final url = message.mediaUrl!;
      final type = (message.mediaType ?? '').toLowerCase();
      final looksImage = type.contains('image') || _isImageUrl(url);
      if (looksImage) {
        return Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 2),
          child: GestureDetector(
            onTap: () => onImageTap(url),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SafeNetworkImage(
                  imageUrl: url,
                  width: 220,
                  height: 220,
                  fit: BoxFit.cover,
                  highQuality: true,
                  errorWidget: Container(
                    width: 220,
                    height: 160,
                    color: scheme.surface,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        return DocumentTile(url: url, isOwn: isOwn, message: message, onMessageOptions: onMessageOptions);
      }
    }

    // If message is a bare URL, try media rendering first
    final parsed = Uri.tryParse(text);
    final looksLikeUrl =
        parsed != null &&
        parsed.hasScheme &&
        (text.startsWith('http://') || text.startsWith('https://'));
    if (looksLikeUrl) {
      if (_isImageUrl(text)) {
        return Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 2),
          child: GestureDetector(
            onTap: () => onImageTap(text),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SafeNetworkImage(
                  imageUrl: text,
                  width: 220,
                  height: 220,
                  fit: BoxFit.cover,
                  highQuality: true,
                  errorWidget: Container(
                    width: 220,
                    height: 160,
                    color: scheme.surface,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      if (_isDocUrl(text)) {
        return DocumentTile(url: text, isOwn: isOwn, message: message, onMessageOptions: onMessageOptions);
      }
      // Generic link tile
      return InkWell(
        onTap: () => onMessageOptions?.call(context, message),
        onLongPress: () {
          HapticFeedback.mediumImpact();
          onMessageOptions?.call(context, message);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.link,
              size: 16,
              color: isOwn
                  ? Theme.of(context).colorScheme.onPrimary
                  : (Theme.of(context).brightness == Brightness.light
                        ? Colors.black
                        : scheme.primary),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  color: isOwn
                      ? Theme.of(context).colorScheme.onPrimary
                      : (Theme.of(context).brightness == Brightness.light
                            ? Colors.black
                            : scheme.primary),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      );
    }

    // Rich text linkify inside normal text
    return DefaultTextStyle.merge(
      style: TextStyle(
        height: 1.35,
        fontSize: 14,
        color: isOwn
            ? Theme.of(context).colorScheme.onPrimary
            : (Theme.of(context).brightness == Brightness.light
                  ? Colors.black
                  : Theme.of(context).colorScheme.onSurface),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: isOwn
                ? Theme.of(context).colorScheme.onPrimary
                : (Theme.of(context).brightness == Brightness.light
                      ? Colors.black
                      : Theme.of(context).colorScheme.onSurface),
          ),
          children: _linkify(context, text),
        ),
      ),
    );
  }
}

class MediaBubble extends StatelessWidget {
  final ChatMessage message;
  final Function(String)? onImageTap;
  final Function(BuildContext, ChatMessage)? onMessageOptions;
  const MediaBubble({super.key, required this.message, this.onImageTap, this.onMessageOptions});

  bool get _isImage => (message.mediaType ?? '').startsWith('image/');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = message.mediaUrl ?? '';
    final name = message.mediaName ?? url.split('/').last;

    if (_isImage) {
      return Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 2),
        child: GestureDetector(
          onTap: () => onImageTap?.call(url),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SafeNetworkImage(
                imageUrl: url,
                width: 220,
                height: 220,
                fit: BoxFit.cover,
                highQuality: true,
                errorWidget: Container(
                  width: 220,
                  height: 160,
                  color: scheme.surface,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Generic document bubble
    final isPDF = (message.mediaType ?? '').contains('pdf') || 
                  url.toLowerCase().endsWith('.pdf') ||
                  name.toLowerCase().endsWith('.pdf');
    final isPowerPoint = url.toLowerCase().endsWith('.ppt') || 
                        url.toLowerCase().endsWith('.pptx') ||
                        name.toLowerCase().endsWith('.ppt') ||
                        name.toLowerCase().endsWith('.pptx');
    final canViewInApp = isPDF || isPowerPoint;
    
    return InkWell(
      onTap: () => onMessageOptions?.call(context, message),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onMessageOptions?.call(context, message);
      },
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: canViewInApp 
                ? scheme.primary.withValues(alpha: 0.5)
                : scheme.outline,
            width: canViewInApp ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Icon(
                  isPDF 
                      ? Icons.picture_as_pdf_outlined
                      : isPowerPoint
                          ? Icons.slideshow_outlined
                          : Icons.insert_drive_file_outlined,
                  color: scheme.primary,
                ),
                if (canViewInApp)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: scheme.surface,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.visibility,
                        size: 8,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: canViewInApp ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                  if (canViewInApp)
                    Text(
                      isPDF ? 'Tap to view' : 'Tap to view presentation',
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else if (message.mediaType != null)
                    Text(
                      message.mediaType!,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.download_rounded, color: scheme.primary, size: 18),
          ],
        ),
      ),
    );
  }
}

class DocumentTile extends StatelessWidget {
  final String url;
  final bool isOwn;
  final ChatMessage message;
  final Function(BuildContext, ChatMessage)? onMessageOptions;
  const DocumentTile({super.key, required this.url, required this.isOwn, required this.message, this.onMessageOptions});

  bool _isPDF() {
    final fileName = message.mediaName ?? url.split('/').last;
    return url.toLowerCase().endsWith('.pdf') || fileName.toLowerCase().endsWith('.pdf');
  }

  bool _isPowerPoint() {
    final fileName = message.mediaName ?? url.split('/').last;
    return url.toLowerCase().endsWith('.ppt') || 
           url.toLowerCase().endsWith('.pptx') ||
           fileName.toLowerCase().endsWith('.ppt') ||
           fileName.toLowerCase().endsWith('.pptx');
  }

  bool _canViewInApp() {
    return _isPDF() || _isPowerPoint();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canViewInApp = _canViewInApp();
    final isPDF = _isPDF();
    final isPowerPoint = _isPowerPoint();
    
    return InkWell(
      onTap: () => onMessageOptions?.call(context, message),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onMessageOptions?.call(context, message);
      },
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isOwn
              ? scheme.primary.withValues(alpha: 0.15)
              : scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: canViewInApp 
                ? scheme.primary.withValues(alpha: 0.5)
                : scheme.outline,
            width: canViewInApp ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Icon(
                  isPDF 
                      ? Icons.picture_as_pdf_outlined
                      : isPowerPoint
                          ? Icons.slideshow_outlined
                          : Icons.insert_drive_file_outlined,
                  color: isOwn ? scheme.onPrimary : scheme.primary,
                ),
                if (canViewInApp)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isOwn ? scheme.primary : scheme.surface,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.visibility,
                        size: 8,
                        color: isOwn ? scheme.onPrimary : scheme.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.mediaName ?? url.split('/').last,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isOwn ? scheme.onPrimary : scheme.onSurface,
                      fontWeight: canViewInApp ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                  if (canViewInApp)
                    Text(
                      isPDF ? 'Tap to view' : 'Tap to view presentation',
                      style: TextStyle(
                        color: isOwn 
                            ? scheme.onPrimary.withValues(alpha: 0.7)
                            : scheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.download_rounded,
              color: isOwn ? scheme.onPrimary : scheme.primary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _downloadImage(context),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareImage(context),
          ),
        ],
      ),
      body: PhotoView(
        imageProvider: NetworkImage(imageUrl),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 2.0,
        initialScale: PhotoViewComputedScale.contained,
        heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
        loadingBuilder: (context, event) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Colors.white,
            size: 64,
          ),
        ),
      ),
    );
  }

  void _downloadImage(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      final directory = await getApplicationDocumentsDirectory();
      final filename = imageUrl.split('/').last.split('?').first;
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(response.bodyBytes);

      if (context.mounted) {
        showAppToast(
          context,
          'Image saved to ${file.path}',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        showAppToast(
          context,
          'Failed to download image: $e',
          type: ToastType.error,
        );
      }
    }
  }

  void _shareImage(BuildContext context) async {
    try {
      await launchUrl(
        Uri.parse(imageUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (context.mounted) {
        showAppToast(
          context,
          'Failed to share image: $e',
          type: ToastType.error,
        );
      }
    }
  }
}

class BeginningHeaderDelegate extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 40.0;

  @override
  double get maxExtent => 40.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Text(
            'Beginning of conversation',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}

class CustomGlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;

  const CustomGlassContainer({
    super.key,
    required this.child,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      scheme.surface.withValues(alpha: 0.2),
                      scheme.surface.withValues(alpha: 0.1),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.25),
                      Colors.white.withValues(alpha: 0.1),
                    ],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark
                  ? scheme.outline.withValues(alpha: 0.2)
                  : scheme.outline.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class CustomGlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;

  const CustomGlassButton({
    super.key,
    required this.child,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          scheme.surface.withValues(alpha: 0.3),
                          scheme.surface.withValues(alpha: 0.15),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.4),
                          Colors.white.withValues(alpha: 0.2),
                        ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? scheme.outline.withValues(alpha: 0.2)
                      : scheme.outline.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
