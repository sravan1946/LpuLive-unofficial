import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';
import 'package:flutter/gestures.dart';
import '../models/chat_message_model.dart';

class MessageBody extends StatelessWidget {
  final ChatMessage message;
  final bool isOwn;
  final Function(String) onImageTap;
  final Function(BuildContext, ChatMessage) onMessageOptions;

  const MessageBody({
    super.key,
    required this.message,
    required this.isOwn,
    required this.onImageTap,
    required this.onMessageOptions,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return SelectableText.rich(
      _buildTextSpan(context),
      style: TextStyle(
        color: isOwn ? scheme.onPrimary : scheme.onSurface,
        fontSize: 16,
        height: 1.3,
      ),
    );
  }

  TextSpan _buildTextSpan(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = message.message;
    final urlRegex = RegExp(
      r'https?://[^\s]+',
      caseSensitive: false,
    );
    
    final matches = urlRegex.allMatches(text);
    if (matches.isEmpty) {
      return TextSpan(text: text);
    }

    final spans = <TextSpan>[];
    int last = 0;

    for (final match in matches) {
      // Add text before the URL
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }

      final url = match.group(0)!;
      final looksImage = _isImageUrl(url);
      
      if (looksImage) {
        spans.add(
          TextSpan(
            text: url,
            style: TextStyle(
              color: isOwn ? scheme.onPrimary : scheme.primary,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w600,
            ),
            recognizer: (TapGestureRecognizer()..onTap = () => onImageTap(url)),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: url,
            style: TextStyle(
              color: isOwn ? scheme.onPrimary : scheme.primary,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w600,
            ),
            recognizer: (TapGestureRecognizer()..onTap = () => _openUrl(url)),
          ),
        );
      }
      last = match.end;
    }

    // Add remaining text
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }

    return TextSpan(children: spans);
  }

  bool _isImageUrl(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('.jpg') ||
        lowerUrl.contains('.jpeg') ||
        lowerUrl.contains('.png') ||
        lowerUrl.contains('.gif') ||
        lowerUrl.contains('.webp') ||
        lowerUrl.contains('.bmp');
  }

  void _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class MediaBubble extends StatelessWidget {
  final ChatMessage message;
  final Function(String) onImageTap;
  final Function(BuildContext, ChatMessage) onMessageOptions;

  const MediaBubble({
    super.key,
    required this.message,
    required this.onImageTap,
    required this.onMessageOptions,
  });

  @override
  Widget build(BuildContext context) {
    final url = message.mediaUrl ?? '';
    final fileName = message.mediaName ?? '';
    final isPDF = url.toLowerCase().endsWith('.pdf') || 
                  fileName.toLowerCase().endsWith('.pdf');
    
    if (isPDF) {
      return _DocumentTile(
        message: message,
        onMessageOptions: onMessageOptions,
      );
    }
    
    if (_isImageUrl(url)) {
      return _ImageTile(
        message: message,
        onImageTap: onImageTap,
        onMessageOptions: onMessageOptions,
      );
    }
    
    return _DocumentTile(
      message: message,
      onMessageOptions: onMessageOptions,
    );
  }

  bool _isImageUrl(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('.jpg') ||
        lowerUrl.contains('.jpeg') ||
        lowerUrl.contains('.png') ||
        lowerUrl.contains('.gif') ||
        lowerUrl.contains('.webp') ||
        lowerUrl.contains('.bmp');
  }
}

class _ImageTile extends StatelessWidget {
  final ChatMessage message;
  final Function(String) onImageTap;
  final Function(BuildContext, ChatMessage) onMessageOptions;

  const _ImageTile({
    required this.message,
    required this.onImageTap,
    required this.onMessageOptions,
  });

  @override
  Widget build(BuildContext context) {
    final url = message.mediaUrl ?? '';
    
    if (_isImageUrl(url)) {
      return Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 2),
        child: GestureDetector(
          onTap: () => onImageTap(url),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.broken_image),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }
    
    return InkWell(
      onTap: () => onMessageOptions(context, message),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onMessageOptions(context, message);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.link),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                url,
                style: const TextStyle(decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isImageUrl(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('.jpg') ||
        lowerUrl.contains('.jpeg') ||
        lowerUrl.contains('.png') ||
        lowerUrl.contains('.gif') ||
        lowerUrl.contains('.webp') ||
        lowerUrl.contains('.bmp');
  }
}

class _DocumentTile extends StatelessWidget {
  final ChatMessage message;
  final Function(BuildContext, ChatMessage) onMessageOptions;

  const _DocumentTile({
    required this.message,
    required this.onMessageOptions,
  });

  @override
  Widget build(BuildContext context) {
    final url = message.mediaUrl ?? '';
    final fileName = message.mediaName ?? 'Unknown file';
    final isPDF = url.toLowerCase().endsWith('.pdf') || 
                  fileName.toLowerCase().endsWith('.pdf');
    
    return InkWell(
      onTap: () => onMessageOptions(context, message),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onMessageOptions(context, message);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              isPDF ? Icons.picture_as_pdf : Icons.insert_drive_file,
              color: isPDF ? Colors.red : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (url.isNotEmpty)
                    Text(
                      url,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        decoration: TextDecoration.underline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: PhotoView(
          imageProvider: NetworkImage(imageUrl),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
        ),
      ),
    );
  }
}
