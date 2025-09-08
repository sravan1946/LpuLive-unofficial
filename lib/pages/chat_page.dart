import 'package:flutter/material.dart';
import 'dart:async';
import '../models/user_models.dart';
import '../services/chat_services.dart';
import '../widgets/network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatPage extends StatefulWidget {
  final String groupId;
  final String title;
  final WebSocketChatService wsService;
  final bool isReadOnly;

  const ChatPage({
    super.key,
    required this.groupId,
    required this.title,
    required this.wsService,
    this.isReadOnly = false,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ChatApiService _apiService = ChatApiService();
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  late final StreamSubscription<ChatMessage> _messageSubscription;

  @override
  void initState() {
    super.initState();
    // Ensure websocket is connected in case parent didn't connect yet
    if (!widget.wsService.isConnected && currentUser != null) {
      widget.wsService.connect(currentUser!.chatToken).catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('WebSocket connect failed: $e')),
          );
        }
      });
    }
    _loadMessages();
    _messageSubscription = widget.wsService.messageStream.listen((message) {
      if (message.group == widget.groupId) {
        setState(() {
          _messages = [..._messages, message];
          _messages.sort((a, b) {
            try {
              final dateA = DateTime.parse(a.timestamp);
              final dateB = DateTime.parse(b.timestamp);
              return dateA.compareTo(dateB);
            } catch (_) {
              return 0;
            }
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (currentUser == null) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final loaded = await _apiService.fetchChatMessages(
        widget.groupId,
        currentUser!.chatToken,
      );
      setState(() {
        _messages = loaded;
        _isLoading = false;
      });

      if (_messages.isNotEmpty) {
        final lastMsg = _messages.last;
        for (int i = 0; i < (currentUser?.groups.length ?? 0); i++) {
          if (currentUser!.groups[i].name == widget.groupId) {
            currentUser!.groups[i] = currentUser!.groups[i].copyWith(
              groupLastMessage: lastMsg.message,
              lastMessageTime: lastMsg.timestamp,
            );
          }
        }
        TokenStorage.saveCurrentUser();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load messages: $e')));
      }
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || widget.isReadOnly) return;

    if (!widget.wsService.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not connected to chat server')),
        );
      }
      return;
    }

    try {
      await widget.wsService.sendMessage(
        message: message,
        group: widget.groupId,
      );

      // Optimistically show message
      final optimistic = ChatMessage(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        message: message,
        sender: currentUser?.id ?? '',
        senderName: currentUser?.displayName ?? currentUser?.name ?? 'You',
        timestamp: DateTime.now().toIso8601String(),
        isOwnMessage: true,
        userImage: currentUser?.userImageUrl,
        category: currentUser?.category,
        group: widget.groupId,
      );
      setState(() {
        _messages = [..._messages, optimistic];
      });

      final timestamp = DateTime.now().toIso8601String();
      if (currentUser != null) {
        for (int i = 0; i < currentUser!.groups.length; i++) {
          if (currentUser!.groups[i].name == widget.groupId) {
            currentUser!.groups[i] = currentUser!.groups[i].copyWith(
              groupLastMessage: message,
              lastMessageTime: timestamp,
            );
          }
        }
        await TokenStorage.saveCurrentUser();
      }

      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading messages...'),
                      ],
                    ),
                  )
                : _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat,
                          size: 64,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to start the conversation!',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [scheme.surface, scheme.surfaceVariant],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ChatPatternPainter(
                              dotColor: scheme.primary.withValues(alpha: 0.06),
                              secondaryDotColor: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.045),
                              spacing: 26,
                              radius: 1.2,
                            ),
                          ),
                        ),
                        RefreshIndicator(
                          onRefresh: _loadMessages,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final String currentSender = message.sender;
                              final String? previousSender = index > 0
                                  ? _messages[index - 1].sender
                                  : null;
                              final bool isNewBlock =
                                  previousSender == null ||
                                  previousSender != currentSender;
                              final bool showLeftAvatar =
                                  !message.isOwnMessage && isNewBlock;
                              final bool showRightAvatar =
                                  message.isOwnMessage && isNewBlock;
                              const double avatarSize = 32;
                              const double avatarGap = 8;
                              return Align(
                                alignment: message.isOwnMessage
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Row(
                                  mainAxisAlignment: message.isOwnMessage
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!message.isOwnMessage)
                                      if (showLeftAvatar) ...[
                                        SafeNetworkImage(
                                          imageUrl: message.userImage ?? '',
                                          width: avatarSize,
                                          height: avatarSize,
                                          errorWidget: CircleAvatar(
                                            radius: avatarSize / 2,
                                            backgroundColor: scheme.primary,
                                            child: Text(
                                              message.senderName.isNotEmpty
                                                  ? message.senderName[0]
                                                        .toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          highQuality: true,
                                          fit: BoxFit.cover,
                                        ),
                                        SizedBox(width: avatarGap),
                                      ] else
                                        const SizedBox(
                                          width: avatarSize + avatarGap,
                                        ),
                                    Flexible(
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: message.isOwnMessage
                                              ? scheme.primary
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.surfaceVariant,
                                          borderRadius: BorderRadius.only(
                                            topLeft: const Radius.circular(14),
                                            topRight: const Radius.circular(14),
                                            bottomLeft: message.isOwnMessage
                                                ? const Radius.circular(14)
                                                : const Radius.circular(4),
                                            bottomRight: message.isOwnMessage
                                                ? const Radius.circular(4)
                                                : const Radius.circular(14),
                                          ),
                                        ),
                                        constraints: BoxConstraints(
                                          maxWidth:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.7,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              message.isOwnMessage
                                              ? CrossAxisAlignment.end
                                              : CrossAxisAlignment.start,
                                          children: [
                                            if (!message.isOwnMessage &&
                                                isNewBlock)
                                              Text(
                                                message.senderName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                  color: scheme.primary,
                                                ),
                                              ),
                                            if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty)
                                              _MediaBubble(message: message)
                                            else
                                              _MessageBody(
                                                message: message,
                                                isOwn: message.isOwnMessage,
                                              ),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  _formatTimestamp(
                                                    message.timestamp,
                                                  ),
                                                  style: TextStyle(
                                                    height: 1.0,
                                                    fontSize: 10,
                                                    color: message.isOwnMessage
                                                        ? scheme.onPrimary
                                                              .withValues(
                                                                alpha: 0.7,
                                                              )
                                                        : Theme.of(context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                  ),
                                                ),
                                                if (message.isOwnMessage) ...[
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    Icons.done_all,
                                                    size: 14,
                                                    color: scheme.onPrimary
                                                        .withValues(alpha: 0.8),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (message.isOwnMessage)
                                      if (showRightAvatar) ...[
                                        SizedBox(width: avatarGap),
                                        SafeNetworkImage(
                                          imageUrl:
                                              currentUser?.userImageUrl ?? '',
                                          width: avatarSize,
                                          height: avatarSize,
                                          errorWidget: CircleAvatar(
                                            radius: avatarSize / 2,
                                            backgroundColor: scheme.primary,
                                            child: Text(
                                              (currentUser?.name.isNotEmpty ??
                                                      false)
                                                  ? currentUser!.name[0]
                                                        .toUpperCase()
                                                  : 'Y',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          highQuality: true,
                                          fit: BoxFit.cover,
                                        ),
                                      ] else
                                        const SizedBox(
                                          width: avatarGap + avatarSize,
                                        ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (!widget.isReadOnly)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(hintText: 'Message'),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Send'),
                    ),
                  ],
                ),
              ),
            ),
          if (widget.isReadOnly)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.visibility,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'This group is read-only',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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
        ],
      ),
    );
  }
}

class _ChatPatternPainter extends CustomPainter {
  final Color dotColor;
  final Color secondaryDotColor;
  final double spacing;
  final double radius;

  _ChatPatternPainter({
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
  bool shouldRepaint(covariant _ChatPatternPainter oldDelegate) {
    return oldDelegate.dotColor != dotColor ||
        oldDelegate.secondaryDotColor != secondaryDotColor ||
        oldDelegate.spacing != spacing ||
        oldDelegate.radius != radius;
  }
}

class _MessageBody extends StatelessWidget {
  final ChatMessage message;
  final bool isOwn;
  const _MessageBody({required this.message, required this.isOwn});

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
      spans.add(TextSpan(text: text.substring(last)));
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
        );
      }
      if (_isDocUrl(text)) {
        return _DocumentTile(url: text, isOwn: isOwn);
      }
      // Generic link tile
      return GestureDetector(
        onTap: () => _openUrl(text),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.link,
              size: 16,
              color: isOwn
                  ? Theme.of(context).colorScheme.onPrimary
                  : scheme.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  color: isOwn
                      ? Theme.of(context).colorScheme.onPrimary
                      : scheme.primary,
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
            : Theme.of(context).colorScheme.onSurface,
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(),
          children: _linkify(context, text),
        ),
      ),
    );
  }
}

class _MediaBubble extends StatelessWidget {
  final ChatMessage message;
  const _MediaBubble({required this.message});

  bool get _isImage => (message.mediaType ?? '').startsWith('image/');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = message.mediaUrl ?? '';
    final name = message.mediaName ?? url.split('/').last;

    if (_isImage) {
      return Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 2),
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
      );
    }

    // Generic document bubble
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline),
        ),
        child: Row(
          children: [
            Icon(
              (message.mediaType ?? '').contains('pdf')
                  ? Icons.picture_as_pdf_outlined
                  : Icons.insert_drive_file_outlined,
              color: scheme.primary,
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
                    style: TextStyle(color: scheme.onSurface),
                  ),
                  if (message.mediaType != null)
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

class _DocumentTile extends StatelessWidget {
  final String url;
  final bool isOwn;
  const _DocumentTile({required this.url, required this.isOwn});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isOwn
              ? scheme.primary.withValues(alpha: 0.15)
              : scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline),
        ),
        child: Row(
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              color: isOwn ? scheme.onPrimary : scheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                url.split('/').last,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isOwn ? scheme.onPrimary : scheme.onSurface,
                ),
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
