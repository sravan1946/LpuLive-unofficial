import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:async';
import '../models/user_models.dart';
import '../models/message_status.dart';
import '../services/chat_services.dart';
import '../services/message_status_service.dart';
import '../widgets/network_image.dart';
import '../services/read_tracker.dart';
import '../widgets/reply_preview.dart';
import '../widgets/message_status_icon.dart';
import '../utils/sender_name_utils.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:photo_view/photo_view.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/app_toast.dart';
import '../widgets/pdf_viewer.dart';

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
  final MessageStatusService _statusService = MessageStatusService();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasReachedTop = false;
  // Removed direction tracking; reversed list uses extentAfter for top detection

  void _stabilizeScrollPosition(int attemptsRemaining, double targetPosition) {
    if (attemptsRemaining <= 0) return;
    if (!_scrollController.hasClients) return;
    try {
      _scrollController.jumpTo(
        targetPosition.clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent,
        ),
      );
      Future.delayed(const Duration(milliseconds: 50), () {
        _stabilizeScrollPosition(attemptsRemaining - 1, targetPosition);
      });
    } catch (_) {
      // ignore failures from jumpTo when controller is not ready
    }
  }

  DateTime? _lastReadAt;
  bool _isLoading = false;
  bool _isSending = false;
  late final StreamSubscription<ChatMessage> _messageSubscription;
  // Reply state
  ChatMessage? _replyingTo;
  // No backend normalization here; media URLs from messages are already normalized in ChatMessage.fromJson

  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final hh = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final mm = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hh:$mm $ampm';
    } catch (e) {
      return timestamp;
    }
  }

  @override
  void initState() {
    super.initState();
    // Ensure websocket is connected in case parent didn't connect yet
    if (!widget.wsService.isConnected && currentUser != null) {
      widget.wsService.connect(currentUser!.chatToken).catchError((e) {
        if (mounted) {
          showAppToast(
            context,
            'WebSocket connect failed: $e',
            type: ToastType.error,
          );
        }
      });
    }
    _loadMessages();
    OpenConversations.open(widget.groupId);
    // Load last-read timestamp to place unread divider
    ConversationReadTracker.getLastReadAt(widget.groupId).then((ts) {
      if (!mounted) return;
      setState(() {
        _lastReadAt = ts;
      });
    });
    _messageSubscription = widget.wsService.messageStream.listen((message) {
      if (message.group == widget.groupId) {
        // Check if this is a server acknowledgment of our local message
        final localMessageIndex = _statusService.findLocalMessageIndex(
          _messages,
          message,
        );

        if (localMessageIndex != -1) {
          // Update the local message with server data and mark as sent
          if (mounted) {
            setState(() {
              _statusService.updateLocalMessageWithServerData(
                _messages,
                localMessageIndex,
                message,
              );
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
          // No auto-scrolling
        } else {
          // Check if message already exists to prevent duplicates
          final messageExists = _messages.any(
            (existingMessage) => existingMessage.id == message.id,
          );

          if (!messageExists && mounted) {
            setState(() {
              _messages = [..._messages, message];
              _statusService.setStatus(message.id, MessageStatus.sent);
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

            // No auto-scrolling when new message arrives
          }
        }
      }
    });
  }

  @override
  void dispose() {
    // Mark as read when leaving the chat
    ConversationReadTracker.setLastReadToNow(widget.groupId);
    OpenConversations.close(widget.groupId);
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription.cancel();
    super.dispose();
  }

  // Auto-scrolling disabled to avoid jank; the list renders from the bottom using reverse: true

  // Determine where to show the unread divider based on last read timestamp
  int? _unreadDividerIndex() {
    if (_lastReadAt == null || _messages.isEmpty) return null;
    // Find first message strictly newer than lastRead
    for (int i = 0; i < _messages.length; i++) {
      try {
        final ts = DateTime.parse(_messages[i].timestamp);
        // Only consider messages from others as unread
        if (ts.isAfter(_lastReadAt!) && !_messages[i].isOwnMessage) {
          // Place divider before this message
          return i;
        }
      } catch (_) {
        // ignore parse errors
      }
    }
    return null;
  }

  // In ascending _messages list, determine whether to show a date header before index
  bool _shouldShowDateHeaderBefore(int index) {
    if (_messages.isEmpty) return false;
    if (index <= 0) return true; // show header before the first item
    final prevTs = _messages[index - 1].timestamp;
    final curTs = _messages[index].timestamp;
    return _isDifferentCalendarDay(prevTs, curTs);
  }

  Future<void> _loadMessages() async {
    if (currentUser == null) return;
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      _currentPage = 1;
      final loaded = await _apiService.fetchChatMessages(
        widget.groupId,
        currentUser!.chatToken,
        page: _currentPage,
      );
      if (mounted) {
        setState(() {
          _messages = loaded;
          _isLoading = false;
          // Initialize status for loaded messages
          _statusService.initializeStatuses(_messages);
        });
      }

      // If there are messages and no last-read marker, set it to the last message
      if (_messages.isNotEmpty && _lastReadAt == null) {
        try {
          _lastReadAt = DateTime.parse(_messages.last.timestamp);
        } catch (_) {}
      }

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

        // No auto-scrolling; list is reversed so latest is at bottom/start
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        showAppToast(
          context,
          'Failed to load messages: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _loadOlderMessages() async {
    if (currentUser == null || _isLoadingMore) return;
    if (mounted) {
      setState(() {
        _isLoadingMore = true;
      });
    }
    try {
      // For reversed list, record current scroll position to maintain it
      final double currentScrollPosition = _scrollController.hasClients
          ? _scrollController.position.pixels
          : 0.0;

      final nextPage = _currentPage + 1;
      final older = await _apiService.fetchChatMessages(
        widget.groupId,
        currentUser!.chatToken,
        page: nextPage,
      );
      if (older.isNotEmpty && mounted) {
        setState(() {
          // older list is ascending; ensure combined stays ascending
          _messages = [...older, ..._messages];
          _currentPage = nextPage;
          _statusService.initializeStatuses(_messages);
        });
        // For reversed list, maintain the same scroll position after prepending
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients) return;
          _scrollController.jumpTo(currentScrollPosition);
          // Additional stabilization passes to account for late image layout
          _stabilizeScrollPosition(3, currentScrollPosition);
        });
      } else {
        // No more messages available - reached the top
        _hasReachedTop = true;
      }
    } catch (e) {
      // Check if this is the "No data found" response indicating we've reached the top
      if (e.toString().contains('No data found')) {
        // Reached the top - no more messages to load
        _hasReachedTop = true;
      } else if (mounted) {
        showAppToast(
          context,
          'Failed to load older messages: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenImageViewer(imageUrl: imageUrl),
      ),
    );
  }

  void _replyToMessage(ChatMessage message) {
    if (mounted) {
      setState(() {
        _replyingTo = message;
      });
    }
    _messageController.clear();
    // Focus on the text field
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelReply() {
    if (mounted) {
      setState(() {
        _replyingTo = null;
      });
    }
  }

  void _showPDFViewer(String pdfUrl, String? fileName) {
    // Navigate to PDF viewer page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PDFViewer(
          pdfUrl: pdfUrl,
          fileName: fileName,
        ),
      ),
    );
  }

  void _downloadPDFDirectly(String pdfUrl, String? fileName) async {
    // Use the same download logic as _downloadMedia
    _downloadMedia(pdfUrl);
  }

  void _showMessageOptions(BuildContext context, ChatMessage message) {
    final url = message.mediaUrl ?? '';
    final fileName = message.mediaName;
    final isPDF = url.toLowerCase().endsWith('.pdf') || 
                  (fileName?.toLowerCase().endsWith('.pdf') ?? false);
    
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reply option (same as regular messages) - hide in read-only chats
              if (!widget.isReadOnly)
                ListTile(
                  leading: const Icon(Icons.reply),
                  title: const Text('Reply'),
                  subtitle: const Text('Reply to this message'),
                  onTap: () {
                    Navigator.pop(context);
                    _replyToMessage(message);
                  },
                ),
              if (isPDF) ...[
                ListTile(
                  leading: const Icon(Icons.visibility),
                  title: const Text('View PDF'),
                  subtitle: const Text('Open in PDF viewer'),
                  onTap: () {
                    Navigator.pop(context);
                    _showPDFViewer(url, fileName);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Download PDF'),
                  subtitle: const Text('Save to Downloads folder'),
                  onTap: () {
                    Navigator.pop(context);
                    _downloadPDFDirectly(url, fileName);
                  },
                ),
              ] else if (url.isNotEmpty) ...[
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Download File'),
                  subtitle: const Text('Save to Downloads folder'),
                  onTap: () {
                    Navigator.pop(context);
                    _downloadMedia(url);
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy text'),
                subtitle: const Text('Copy message content'),
                onTap: () {
                  Navigator.pop(context);
                  _copyMessageText(message);
                },
              ),
              if (url.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.open_in_browser),
                  title: const Text('Open in Browser'),
                  subtitle: const Text('View in external app'),
                  onTap: () async {
                    Navigator.pop(context);
                    final uri = Uri.parse(url);
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
            ],
          ),
        );
      },
    );
  }


  void _downloadMedia(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      final directory = await getApplicationDocumentsDirectory();
      final filename = url.split('/').last.split('?').first;
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(response.bodyBytes);

      if (mounted) {
        showAppToast(
          context,
          'Downloaded to ${file.path}',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Failed to download: $e', type: ToastType.error);
      }
    }
  }

  void _copyMessageText(ChatMessage message) {
    // Copy message text to clipboard
    Clipboard.setData(ClipboardData(text: message.message));
    showAppToast(context, 'Text copied to clipboard', type: ToastType.success);
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || widget.isReadOnly || _isSending) return;

    if (!widget.wsService.isConnected) {
      if (mounted) {
        showAppToast(
          context,
          'Not connected to chat server',
          type: ToastType.warning,
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSending = true;
      });
    }

    // Capture reply target before clearing state
    final String? capturedReplyToId = _replyingTo?.id;
    final String? capturedReplyMessage = _replyingTo?.message;
    final String? capturedReplyUserId = _replyingTo?.sender;

    // Create optimistic message with sending status
    final localMessageId = 'local-${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = ChatMessage(
      id: localMessageId,
      message: message,
      sender: currentUser?.id ?? '',
      senderName: currentUser?.displayName ?? currentUser?.name ?? 'You',
      timestamp: DateTime.now().toIso8601String(),
      isOwnMessage: true,
      userImage: currentUser?.userImageUrl,
      category: currentUser?.category,
      group: widget.groupId,
      replyMessageId: capturedReplyToId,
      replyType: capturedReplyToId != null ? 'p' : null,
      replyMessage: capturedReplyMessage,
      replyUserId: capturedReplyUserId,
    );

    // Add optimistic message with sending status
    if (mounted) {
      setState(() {
        _messages = [..._messages, optimistic];
        _statusService.setStatus(localMessageId, MessageStatus.sending);
        _replyingTo = null;
        _isSending = false;
        // Sending marks conversation as read; divider should disappear instantly
        _lastReadAt = DateTime.now();
      });
    }

    // Sending a message should clear unread divider going forward
    ConversationReadTracker.setLastReadToNow(widget.groupId);

    // No auto-scrolling

    try {
      await widget.wsService.sendMessage(
        message: message,
        group: widget.groupId,
        replyToMessageId: capturedReplyToId,
      );

      _messageController.clear();

      // No auto-scrolling after input clears

      // Update group last message info
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          // Remove the failed message from the UI
          _messages.removeWhere((msg) => msg.id == localMessageId);
          _statusService.removeStatus(localMessageId);
        });
        showAppToast(
          context,
          'Failed to send message: $e',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: Stack(
        children: [
          Positioned.fill(
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
                        colors: [
                          scheme.surface,
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                        ],
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
                        NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n is ScrollUpdateNotification &&
                                n.metrics.extentAfter <= 8 &&
                                !_isLoadingMore &&
                                !_isLoading &&
                                !_hasReachedTop &&
                                _messages.length >= 25) {
                              _loadOlderMessages();
                            }
                            return false;
                          },
                          child: CustomScrollView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            reverse: true,
                            slivers: [
                              // Messages list
                              SliverPadding(
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  _replyingTo != null ? 160 : 80,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      // When reversed, adjust divider placement and message index mapping
                                      final dividerAt = _unreadDividerIndex();
                                      if (dividerAt != null &&
                                          index ==
                                              (_messages.length - dividerAt)) {
                                        return const _UnreadDivider();
                                      }
                                      final realIndexFromBottom =
                                          index -
                                          (dividerAt != null &&
                                                  index >
                                                      (_messages.length -
                                                          dividerAt)
                                              ? 1
                                              : 0);
                                      final realIndex =
                                          (_messages.length - 1) -
                                          realIndexFromBottom;
                                      final message = _messages[realIndex];
                                      final String currentSender =
                                          message.sender;
                                      final String? previousSender =
                                          realIndex > 0
                                          ? _messages[realIndex - 1].sender
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
                                      final bool showDateHeader =
                                          _shouldShowDateHeaderBefore(
                                            realIndex,
                                          );
                                      final messageWidget = Align(
                                        alignment: message.isOwnMessage
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: Row(
                                          mainAxisAlignment:
                                              message.isOwnMessage
                                              ? MainAxisAlignment.end
                                              : MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (!message.isOwnMessage)
                                              if (showLeftAvatar) ...[
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        avatarSize / 2,
                                                      ),
                                                  child: SafeNetworkImage(
                                                    imageUrl:
                                                        message.userImage ?? '',
                                                    width: avatarSize,
                                                    height: avatarSize,
                                                    errorWidget: CircleAvatar(
                                                      radius: avatarSize / 2,
                                                      backgroundColor:
                                                          scheme.primary,
                                                      child: Text(
                                                        message
                                                                .senderName
                                                                .isNotEmpty
                                                            ? message
                                                                  .senderName[0]
                                                                  .toUpperCase()
                                                            : '?',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    highQuality: true,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                                SizedBox(width: avatarGap),
                                              ] else
                                                const SizedBox(
                                                  width: avatarSize + avatarGap,
                                                ),
                                            Flexible(
                                              child: _SwipeToReplyMessage(
                                                message: message,
                                                isReadOnly: widget.isReadOnly,
                                                onReply: () => _replyToMessage(message),
                                                onLongPress: () {
                                                  HapticFeedback.mediumImpact();
                                                  _showMessageOptions(
                                                    context,
                                                    message,
                                                  );
                                                },
                                                child: Container(
                                                  margin: const EdgeInsets.only(
                                                    bottom: 8,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 10,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: message.isOwnMessage
                                                        ? scheme.primary
                                                        : Theme.of(context)
                                                              .colorScheme
                                                              .surfaceContainerHighest,
                                                    border: message.isOwnMessage
                                                        ? null
                                                        : Border.all(
                                                            color:
                                                                scheme.outline,
                                                          ),
                                                    borderRadius: BorderRadius.only(
                                                      topLeft:
                                                          const Radius.circular(
                                                            14,
                                                          ),
                                                      topRight:
                                                          const Radius.circular(
                                                            14,
                                                          ),
                                                      bottomLeft:
                                                          message.isOwnMessage
                                                          ? const Radius.circular(
                                                              14,
                                                            )
                                                          : const Radius.circular(
                                                              4,
                                                            ),
                                                      bottomRight:
                                                          message.isOwnMessage
                                                          ? const Radius.circular(
                                                              4,
                                                            )
                                                          : const Radius.circular(
                                                              14,
                                                            ),
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
                                                        : CrossAxisAlignment
                                                              .start,
                                                    children: [
                                                      if (!message
                                                              .isOwnMessage &&
                                                          isNewBlock)
                                                        Text(
                                                          message.senderName,
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 12,
                                                            color:
                                                                message
                                                                    .isOwnMessage
                                                                ? scheme
                                                                      .onPrimary
                                                                : scheme
                                                                      .primary,
                                                          ),
                                                        ),
                                                      // Reply preview
                                                      if (message
                                                              .replyMessageId !=
                                                          null)
                                                        ReplyPreview(
                                                          message: message,
                                                          isOwn: message
                                                              .isOwnMessage,
                                                          allMessages:
                                                              _messages,
                                                        ),
                                                      if (message.mediaUrl !=
                                                              null &&
                                                          message
                                                              .mediaUrl!
                                                              .isNotEmpty)
                                                        _MediaBubble(
                                                          message: message,
                                                          onImageTap:
                                                              _showFullScreenImage,
                                                          onMessageOptions: _showMessageOptions,
                                                        )
                                                      else
                                                        _MessageBody(
                                                          message: message,
                                                          isOwn: message
                                                              .isOwnMessage,
                                                          onImageTap:
                                                              _showFullScreenImage,
                                                          onMessageOptions: _showMessageOptions,
                                                        ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .end,
                                                        children: [
                                                          Text(
                                                            _formatTimestamp(
                                                              message.timestamp,
                                                            ),
                                                            style: TextStyle(
                                                              height: 1.0,
                                                              fontSize: 10,
                                                              color:
                                                                  message
                                                                      .isOwnMessage
                                                                  ? scheme
                                                                        .onPrimary
                                                                        .withValues(
                                                                          alpha:
                                                                              0.7,
                                                                        )
                                                                  : scheme
                                                                        .onSurfaceVariant,
                                                            ),
                                                          ),
                                                          if (message
                                                              .isOwnMessage) ...[
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            MessageStatusIcon(
                                                              status:
                                                                  _statusService
                                                                      .getStatus(
                                                                        message
                                                                            .id,
                                                                      ),
                                                              scheme: scheme,
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (message.isOwnMessage)
                                              if (showRightAvatar) ...[
                                                SizedBox(width: avatarGap),
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        avatarSize / 2,
                                                      ),
                                                  child: SafeNetworkImage(
                                                    imageUrl:
                                                        currentUser
                                                            ?.userImageUrl ??
                                                        '',
                                                    width: avatarSize,
                                                    height: avatarSize,
                                                    errorWidget: CircleAvatar(
                                                      radius: avatarSize / 2,
                                                      backgroundColor:
                                                          scheme.primary,
                                                      child: Text(
                                                        (currentUser
                                                                    ?.name
                                                                    .isNotEmpty ??
                                                                false)
                                                            ? currentUser!
                                                                  .name[0]
                                                                  .toUpperCase()
                                                            : 'Y',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    highQuality: true,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ] else
                                                const SizedBox(
                                                  width: avatarGap + avatarSize,
                                                ),
                                          ],
                                        ),
                                      );

                                      if (showDateHeader) {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            _DateBanner(
                                              label: _dateLabelFor(
                                                message.timestamp,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            messageWidget,
                                          ],
                                        );
                                      }
                                      return messageWidget;
                                    },
                                    childCount:
                                        _messages.length +
                                        (_unreadDividerIndex() == null ? 0 : 1),
                                  ),
                                ),
                              ),
                              // Beginning of conversation header (pinned at top)
                              if (_hasReachedTop && _messages.isNotEmpty)
                                SliverPersistentHeader(
                                  pinned: true,
                                  delegate: _BeginningHeaderDelegate(),
                                ),
                            ],
                          ),
                        ),
                        // Loading older messages indicator (top overlay)
                        if (_isLoadingMore)
                          Positioned(
                            top: 8,
                            left: 0,
                            right: 0,
                            child: IgnorePointer(
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface
                                        .withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Loading older messages...',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Mark messages read when user reaches bottom (opens chat)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              if (n.metrics.pixels >=
                                  n.metrics.maxScrollExtent - 24) {
                                ConversationReadTracker.setLastReadToNow(
                                  widget.groupId,
                                );
                                _lastReadAt = DateTime.now();
                              }
                              return false;
                            },
                            child: const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (!widget.isReadOnly)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyingTo != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: scheme.outline),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 3,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Replying to ${SenderNameUtils.parseSenderName(_replyingTo!.senderName)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: scheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _replyingTo!.message,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: scheme.onSurface,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _cancelReply,
                                icon: Icon(
                                  Icons.close,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    _CustomGlassContainer(
                      borderRadius: 16,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                minLines: 1,
                                maxLines: 5,
                                textInputAction: TextInputAction.newline,
                                decoration: const InputDecoration(
                                  hintText: 'Message',
                                  filled: false,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _CustomGlassButton(
                              onPressed: _sendMessage,
                              child: Icon(
                                Icons.send_rounded,
                                color: scheme.primary,
                                size: 22,
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
          if (widget.isReadOnly)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
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

class _SwipeToReplyMessage extends StatefulWidget {
  final ChatMessage message;
  final bool isReadOnly;
  final VoidCallback onReply;
  final VoidCallback onLongPress;
  final Widget child;

  const _SwipeToReplyMessage({
    required this.message,
    required this.isReadOnly,
    required this.onReply,
    required this.onLongPress,
    required this.child,
  });

  @override
  State<_SwipeToReplyMessage> createState() => _SwipeToReplyMessageState();
}

class _SwipeToReplyMessageState extends State<_SwipeToReplyMessage>
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

class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider();

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

class _DateBanner extends StatelessWidget {
  final String label;
  const _DateBanner({required this.label});

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

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _dateLabelFor(String isoTs) {
  DateTime dt;
  try {
    dt = DateTime.parse(isoTs).toLocal();
  } catch (_) {
    return '';
  }
  final now = DateTime.now();
  final yesterday = now.subtract(const Duration(days: 1));
  if (_isSameDay(dt, now)) return 'Today';
  if (_isSameDay(dt, yesterday)) return 'Yesterday';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

bool _isDifferentCalendarDay(String prevIso, String curIso) {
  try {
    final p = DateTime.parse(prevIso).toLocal();
    final c = DateTime.parse(curIso).toLocal();
    return !_isSameDay(p, c);
  } catch (_) {
    return false;
  }
}

class _MessageBody extends StatelessWidget {
  final ChatMessage message;
  final bool isOwn;
  final Function(String) onImageTap;
  final Function(BuildContext, ChatMessage)? onMessageOptions;

  const _MessageBody({
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
        return _DocumentTile(url: url, isOwn: isOwn, message: message, onMessageOptions: onMessageOptions);
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
        return _DocumentTile(url: text, isOwn: isOwn, message: message, onMessageOptions: onMessageOptions);
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

class _MediaBubble extends StatelessWidget {
  final ChatMessage message;
  final Function(String)? onImageTap;
  final Function(BuildContext, ChatMessage)? onMessageOptions;
  const _MediaBubble({required this.message, this.onImageTap, this.onMessageOptions});

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
  final ChatMessage message;
  final Function(BuildContext, ChatMessage)? onMessageOptions;
  const _DocumentTile({required this.url, required this.isOwn, required this.message, this.onMessageOptions});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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

class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImageViewer({required this.imageUrl});

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

class _BeginningHeaderDelegate extends SliverPersistentHeaderDelegate {
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

class _CustomGlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;

  const _CustomGlassContainer({
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

class _CustomGlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;

  const _CustomGlassButton({
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
