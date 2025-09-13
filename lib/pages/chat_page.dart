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
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../widgets/app_toast.dart';
import '../widgets/pdf_viewer.dart';
import '../widgets/swipe_to_reply_message.dart';
import '../widgets/message_widgets.dart';
import '../widgets/chat_ui_widgets.dart';
import '../utils/chat_utils.dart';

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
    return ChatUtils.isDifferentCalendarDay(prevTs, curTs);
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
        builder: (context) => FullScreenImageViewer(imageUrl: imageUrl),
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
                            painter: ChatPatternPainter(
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
                                        return const UnreadDivider(unreadCount: 0);
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
                                              child: SwipeToReplyMessage(
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
                                                        MediaBubble(
                                                          message: message,
                                                          onImageTap:
                                                              _showFullScreenImage,
                                                          onMessageOptions: _showMessageOptions,
                                                        )
                                                      else
                                                        MessageBody(
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
                                                            ChatUtils.formatTimestamp(
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
                                            DateBanner(
                                              dateLabel: ChatUtils.dateLabelFor(
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
                                  delegate: BeginningHeaderDelegate(child: Container()),
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
                    CustomGlassContainer(
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
                            CustomGlassButton(
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
