// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Project imports:
import '../models/current_user_state.dart';
import '../models/message_status.dart';
import '../models/user_models.dart';
import '../services/avatar_cache_service.dart';
import '../services/chat_data.dart';
import '../services/chat_handlers.dart';
import '../services/chat_services.dart';
import '../services/message_status_service.dart';
import '../services/read_tracker.dart';
import '../utils/chat_utils.dart';
import '../utils/sender_name_utils.dart';
import '../widgets/app_toast.dart';
import '../widgets/chat_widgets.dart';
import '../widgets/message_status_icon.dart';
import '../widgets/network_image.dart';
import '../widgets/reply_preview.dart';
import 'group_details_page.dart';
import 'group_media_page.dart';

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

  DateTime? _lastReadAt;
  bool _isLoading = false;
  bool _isSending = false;
  late final StreamSubscription<ChatMessage> _messageSubscription;

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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

  Future<void> _confirmAndLeaveChat() async {
    if (currentUser == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave chat?'),
        content: const Text('You will stop receiving messages from this chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final res = await _apiService.performGroupAction(
        currentUser!.chatToken,
        'Leave',
        widget.groupId,
      );

      if (res.isSuccess) {
        if (mounted) {
          showAppToast(context, 'Left chat', type: ToastType.success);
          Navigator.of(context).maybePop();
        }
      } else {
        if (mounted) {
          showAppToast(
            context,
            'Failed: ${res.message}',
            type: ToastType.error,
          );
        }
      }
    } catch (e) {
      showAppToast(context, 'Failed to leave chat: $e', type: ToastType.error);
    }
  }

  Future<void> _confirmAndDeleteChat() async {
    if (currentUser == null) return;
    final scheme = Theme.of(context).colorScheme;
    final controller = TextEditingController();
    final requiredText = widget.groupId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete chat?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This action is permanent and will delete the chat for all members.',
              ),
              const SizedBox(height: 16),
              Text(
                'Type the group id to confirm:',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: requiredText,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () {
                if (controller.text.trim() == requiredText) {
                  Navigator.of(ctx).pop(true);
                }
              },
              style: ButtonStyle(
                foregroundColor: WidgetStatePropertyAll<Color>(
                  scheme.onErrorContainer,
                ),
                backgroundColor: WidgetStatePropertyAll<Color>(
                  scheme.errorContainer,
                ),
              ),
              child: const Text('Delete Chat'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      if (mounted) {
        showAppToast(context, 'Deletion cancelled', type: ToastType.info);
      }
      return;
    }

    try {
      final res = await _apiService.performCriticalGroupAction(
        currentUser!.chatToken,
        'deletegroup',
        widget.groupId,
      );

      if (res.isSuccess) {
        if (mounted) {
          showAppToast(context, 'Chat deleted', type: ToastType.success);
          Navigator.of(context).maybePop();
        }
      } else {
        if (mounted) {
          showAppToast(
            context,
            'Failed: ${res.message}',
            type: ToastType.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Error: $e', type: ToastType.error);
      }
    }
  }

  Future<void> _confirmAndBlockUser({required bool isCurrentlyBlocked}) async {
    if (currentUser == null) return;
    final action = isCurrentlyBlocked ? 'Unblock' : 'Block';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCurrentlyBlocked ? 'Unblock user?' : 'Block user?'),
        content: Text(
          isCurrentlyBlocked
              ? 'You will be able to receive messages from this user again.'
              : 'You will no longer receive messages from this user. You can unblock later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: isCurrentlyBlocked ? Colors.green : Colors.red,
            ),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await _apiService.performGroupAction(
        currentUser!.chatToken,
        action,
        widget.groupId,
      );
      if (result.isSuccess) {
        if (mounted) {
          showAppToast(
            context,
            isCurrentlyBlocked ? 'User unblocked' : 'User blocked',
            type: ToastType.success,
          );
          Navigator.of(context).maybePop();
        }
      } else {
        if (mounted) {
          showAppToast(
            context,
            'Failed: ${result.message}',
            type: ToastType.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          'Failed to ${action.toLowerCase()} user: $e',
          type: ToastType.error,
        );
      }
    }
  }

  late final VoidCallback _userListener;
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
    ChatData.loadMessages(
      context,
      widget.groupId,
      _apiService,
      (loading) => setState(() => _isLoading = loading),
      (messages) => setState(() => _messages = messages),
      (page) => setState(() => _currentPage = page),
      _statusService,
      (lastReadAt) => setState(() => _lastReadAt = lastReadAt),
    );
    OpenConversations.open(widget.groupId);
    // Load last-read timestamp to place unread divider
    ConversationReadTracker.getLastReadAt(widget.groupId).then((ts) {
      if (!mounted) return;
      setState(() {
        _lastReadAt = ts;
      });
    });
    _messageSubscription = widget.wsService.messageStream.listen((message) {
      // Handle delete event early by matching on message_id in current list,
      // regardless of group value in the payload.
      if (message.message.trim().toLowerCase() == 'message deleted') {
        final existsInThisChat = _messages.any((m) => m.id == message.id);
        if (existsInThisChat && mounted) {
          setState(() {
            _messages = _messages.where((m) => m.id != message.id).toList();
            _statusService.removeStatus(message.id);
          });
          showAppToast(context, 'Message deleted', type: ToastType.info);
          return;
        }
        // If not found in current list, continue to other handlers
      }

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
    // Re-render on currentUser updates (e.g., after authorize refresh)
    _userListener = () {
      if (!mounted) return;
      setState(() {});
    };
    currentUserNotifier.addListener(_userListener);

    // Ensure avatar cache is loaded so cached avatars render in this page
    AvatarCacheService.loadCache().then((_) {
      if (mounted) setState(() {});
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
    currentUserNotifier.removeListener(_userListener);
    super.dispose();
  }

  // Auto-scrolling disabled to avoid jank; the list renders from the bottom using reverse: true

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Resolve a small avatar for the app bar (prefer last non-own message avatar in DMs)
    String? _appBarAvatarUrl;
    String? _appBarDisplayName;
    for (int i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (!m.isOwnMessage && (m.userImage != null && m.userImage!.isNotEmpty)) {
        _appBarAvatarUrl = m.userImage;
      }
      if (!m.isOwnMessage && (m.senderName.isNotEmpty)) {
        _appBarDisplayName = m.senderName;
      }
    }
    final bool isDm =
        (currentUser?.groups.any(
              (g) => g.name == widget.groupId && g.isDirectMessage,
            ) ??
            false) ||
        RegExp(r'^\d+\s*:\s*\d+$').hasMatch(widget.groupId);
    // Prefer cached avatar for DM other participant if available
    if (isDm) {
      final parts = widget.groupId.split(':').map((s) => s.trim()).toList();
      if (parts.length == 2) {
        String otherId;
        if (currentUser != null &&
            (parts[0] == currentUser!.id || parts[1] == currentUser!.id)) {
          otherId = parts[0] == currentUser!.id ? parts[1] : parts[0];
        } else {
          otherId = parts[0];
        }
        final cached = AvatarCacheService.getCachedAvatar(otherId);
        if (cached != null && cached.isNotEmpty) {
          _appBarAvatarUrl = cached;
        }
      }
    }
    // Determine user role in this chat
    final userGroup = (currentUser?.groups
            .where((g) => g.name == widget.groupId)
            .toList()
            .cast<Group>() ??
        []);
    final bool isParticipant = userGroup.isNotEmpty && userGroup.first.isActive;
    final bool isAdminOfGroup =
        userGroup.isNotEmpty && (userGroup.first.isAdmin == true);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        leadingWidth: 48,
        titleSpacing: 0,
        title: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => GroupDetailsPage(
                  groupName: widget.groupId,
                  groupId: widget.groupId,
                ),
              ),
            );
          },
          child: Row(
            children: [
              const SizedBox(width: 4),
              if (isDm)
                (_appBarAvatarUrl != null && _appBarAvatarUrl.isNotEmpty)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SafeNetworkImage(
                          imageUrl: _appBarAvatarUrl,
                          width: 32,
                          height: 32,
                          highQuality: true,
                          fit: BoxFit.cover,
                        ),
                      )
                    : CircleAvatar(
                        radius: 16,
                        backgroundColor: scheme.primary,
                        child: Text(
                          widget.title.isNotEmpty
                              ? widget.title[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: scheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      )
              else
                CircleAvatar(
                  radius: 16,
                  backgroundColor: scheme.primary,
                  child: Icon(Icons.group, size: 18, color: scheme.onPrimary),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isDm
                      ? SenderNameUtils.parseSenderName(
                          (_appBarDisplayName?.trim().isNotEmpty == true
                              ? _appBarDisplayName!.trim()
                              : widget.title),
                        )
                      : widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            position: PopupMenuPosition.under,
            offset: const Offset(0, 8),
            onSelected: (value) async {
              switch (value) {
                case 'details':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => GroupDetailsPage(
                        groupName: widget.groupId,
                        groupId: widget.groupId,
                      ),
                    ),
                  );
                  break;
                case 'media':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => GroupMediaPage(
                        groupName: widget.groupId,
                        groupId: widget.groupId,
                      ),
                    ),
                  );
                  break;
                case 'leave':
                  await _confirmAndLeaveChat();
                  break;
                case 'delete':
                  await _confirmAndDeleteChat();
                  break;
                case 'block':
                  await _confirmAndBlockUser(
                    isCurrentlyBlocked:
                        (userGroup.isNotEmpty &&
                                userGroup.first.inviteStatus
                                        .trim()
                                        .toUpperCase() ==
                                    'BLOCK'),
                  );
                  break;
              }
            },
            itemBuilder: (context) {
              final items = <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'details',
                  child: Text('View details'),
                ),
                const PopupMenuItem<String>(
                  value: 'media',
                  child: Text('View media'),
                ),
              ];
              if (isAdminOfGroup) {
                items.add(
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Delete chat'),
                  ),
                );
              } else if (isParticipant) {
                items.add(
                  const PopupMenuItem<String>(
                    value: 'leave',
                    child: Text('Leave chat'),
                  ),
                );
              }
              if (isDm) {
                final isBlocked = userGroup.isNotEmpty &&
                    userGroup.first.inviteStatus.trim().toUpperCase() ==
                        'BLOCK';
                items.add(PopupMenuItem<String>(
                  value: 'block',
                  child: Text(isBlocked ? 'Unblock user' : 'Block user'),
                ));
              }
              return items;
            },
          ),
        ],
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
                              ChatData.loadOlderMessages(
                                context,
                                widget.groupId,
                                _apiService,
                                _scrollController,
                                _currentPage,
                                (page) => setState(() => _currentPage = page),
                                _messages,
                                (messages) =>
                                    setState(() => _messages = messages),
                                (loading) =>
                                    setState(() => _isLoadingMore = loading),
                                (reached) =>
                                    setState(() => _hasReachedTop = reached),
                                _statusService,
                              );
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
                                      final dividerAt =
                                          ChatUtils.unreadDividerIndex(
                                            _messages,
                                            _lastReadAt,
                                          );
                                      if (dividerAt != null &&
                                          index ==
                                              (_messages.length - dividerAt)) {
                                        return const UnreadDivider();
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
                                      // Start a new visual block when sender changes or calendar day changes
                                      final bool dateChangedFromPrev =
                                          realIndex > 0
                                          ? _isDifferentCalendarDay(
                                              _messages[realIndex - 1]
                                                  .timestamp,
                                              message.timestamp,
                                            )
                                          : true;
                                      final bool isNewBlock =
                                          previousSender == null ||
                                          previousSender != currentSender ||
                                          dateChangedFromPrev;
                                      final bool showLeftAvatar =
                                          !message.isOwnMessage && isNewBlock;
                                      final bool showRightAvatar =
                                          message.isOwnMessage && isNewBlock;
                                      const double avatarSize = 32;
                                      const double avatarGap = 8;
                                      final bool showDateHeader =
                                          ChatUtils.shouldShowDateHeaderBefore(
                                            _messages,
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
                                                        AvatarCacheService.getCachedAvatar(
                                                          message.sender,
                                                        ) ??
                                                        (message.userImage ??
                                                            ''),
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
                                                onReply: () =>
                                                    ChatHandlers.replyToMessage(
                                                      context,
                                                      message,
                                                      (replyingTo) => setState(
                                                        () => _replyingTo =
                                                            replyingTo,
                                                      ),
                                                      _messageController,
                                                    ),
                                                onLongPress: () {
                                                  HapticFeedback.mediumImpact();
                                                  final isAdmin =
                                                      (currentUser?.groups
                                                          .firstWhere(
                                                            (g) =>
                                                                g.name ==
                                                                widget.groupId,
                                                            orElse: () => Group(
                                                              name: widget
                                                                  .groupId,
                                                              groupLastMessage:
                                                                  '',
                                                              lastMessageTime:
                                                                  '',
                                                              isActive: true,
                                                              isAdmin: false,
                                                              inviteStatus: '',
                                                              isTwoWay: false,
                                                              isOneToOne: false,
                                                            ),
                                                          )
                                                          .isAdmin) ==
                                                      true;
                                                  ChatHandlers.showMessageOptions(
                                                    context,
                                                    message,
                                                    widget.isReadOnly,
                                                    (msg) =>
                                                        ChatHandlers.replyToMessage(
                                                          context,
                                                          msg,
                                                          (
                                                            replyingTo,
                                                          ) => setState(
                                                            () => _replyingTo =
                                                                replyingTo,
                                                          ),
                                                          _messageController,
                                                        ),
                                                    (url, fileName) =>
                                                        ChatHandlers.showPDFViewer(
                                                          context,
                                                          url,
                                                          fileName,
                                                        ),
                                                    (
                                                      url,
                                                      fileName,
                                                    ) => ChatHandlers.downloadPDFDirectly(
                                                      url,
                                                      fileName,
                                                      (url) =>
                                                          ChatHandlers.downloadMedia(
                                                            context,
                                                            url,
                                                          ),
                                                    ),
                                                    (url) =>
                                                        ChatHandlers.downloadMedia(
                                                          context,
                                                          url,
                                                        ),
                                                    (msg) =>
                                                        ChatHandlers.copyMessageText(
                                                          context,
                                                          msg,
                                                        ),
                                                    isAdmin: isAdmin,
                                                    onDelete: (msg) async {
                                                      await ChatHandlers.deleteMessage(
                                                        context,
                                                        widget.wsService,
                                                        msg,
                                                      );
                                                    },
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
                                                          SenderNameUtils.parseSenderName(
                                                            message.senderName,
                                                          ),
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
                                                          onImageTap: (url) =>
                                                              ChatHandlers.showFullScreenImage(
                                                                context,
                                                                url,
                                                              ),
                                                          onMessageOptions: (ctx, msg) => ChatHandlers.showMessageOptions(
                                                            ctx,
                                                            msg,
                                                            widget.isReadOnly,
                                                            (
                                                              replyMsg,
                                                            ) => ChatHandlers.replyToMessage(
                                                              ctx,
                                                              replyMsg,
                                                              (
                                                                replyingTo,
                                                              ) => setState(
                                                                () => _replyingTo =
                                                                    replyingTo,
                                                              ),
                                                              _messageController,
                                                            ),
                                                            (url, fileName) =>
                                                                ChatHandlers.showPDFViewer(
                                                                  ctx,
                                                                  url,
                                                                  fileName,
                                                                ),
                                                            (
                                                              url,
                                                              fileName,
                                                            ) => ChatHandlers.downloadPDFDirectly(
                                                              url,
                                                              fileName,
                                                              (url) =>
                                                                  ChatHandlers.downloadMedia(
                                                                    ctx,
                                                                    url,
                                                                  ),
                                                            ),
                                                            (url) =>
                                                                ChatHandlers.downloadMedia(
                                                                  ctx,
                                                                  url,
                                                                ),
                                                            (msg) =>
                                                                ChatHandlers.copyMessageText(
                                                                  ctx,
                                                                  msg,
                                                                ),
                                                            isAdmin:
                                                                (currentUser
                                                                    ?.groups
                                                                    .firstWhere(
                                                                      (g) =>
                                                                          g.name ==
                                                                          widget
                                                                              .groupId,
                                                                      orElse: () => Group(
                                                                        name: widget
                                                                            .groupId,
                                                                        groupLastMessage:
                                                                            '',
                                                                        lastMessageTime:
                                                                            '',
                                                                        isActive:
                                                                            true,
                                                                        isAdmin:
                                                                            false,
                                                                        inviteStatus:
                                                                            '',
                                                                        isTwoWay:
                                                                            false,
                                                                        isOneToOne:
                                                                            false,
                                                                      ),
                                                                    )
                                                                    .isAdmin) ==
                                                                true,
                                                            onDelete: (m) async {
                                                              await ChatHandlers.deleteMessage(
                                                                ctx,
                                                                widget
                                                                    .wsService,
                                                                m,
                                                              );
                                                            },
                                                          ),
                                                        )
                                                      else
                                                        MessageBody(
                                                          message: message,
                                                          isOwn: message
                                                              .isOwnMessage,
                                                          onImageTap: (url) =>
                                                              ChatHandlers.showFullScreenImage(
                                                                context,
                                                                url,
                                                              ),
                                                          onMessageOptions: (ctx, msg) => ChatHandlers.showMessageOptions(
                                                            ctx,
                                                            msg,
                                                            widget.isReadOnly,
                                                            (
                                                              replyMsg,
                                                            ) => ChatHandlers.replyToMessage(
                                                              ctx,
                                                              replyMsg,
                                                              (
                                                                replyingTo,
                                                              ) => setState(
                                                                () => _replyingTo =
                                                                    replyingTo,
                                                              ),
                                                              _messageController,
                                                            ),
                                                            (url, fileName) =>
                                                                ChatHandlers.showPDFViewer(
                                                                  ctx,
                                                                  url,
                                                                  fileName,
                                                                ),
                                                            (
                                                              url,
                                                              fileName,
                                                            ) => ChatHandlers.downloadPDFDirectly(
                                                              url,
                                                              fileName,
                                                              (url) =>
                                                                  ChatHandlers.downloadMedia(
                                                                    ctx,
                                                                    url,
                                                                  ),
                                                            ),
                                                            (url) =>
                                                                ChatHandlers.downloadMedia(
                                                                  ctx,
                                                                  url,
                                                                ),
                                                            (msg) =>
                                                                ChatHandlers.copyMessageText(
                                                                  ctx,
                                                                  msg,
                                                                ),
                                                            isAdmin:
                                                                (currentUser
                                                                    ?.groups
                                                                    .firstWhere(
                                                                      (g) =>
                                                                          g.name ==
                                                                          widget
                                                                              .groupId,
                                                                      orElse: () => Group(
                                                                        name: widget
                                                                            .groupId,
                                                                        groupLastMessage:
                                                                            '',
                                                                        lastMessageTime:
                                                                            '',
                                                                        isActive:
                                                                            true,
                                                                        isAdmin:
                                                                            false,
                                                                        inviteStatus:
                                                                            '',
                                                                        isTwoWay:
                                                                            false,
                                                                        isOneToOne:
                                                                            false,
                                                                      ),
                                                                    )
                                                                    .isAdmin) ==
                                                                true,
                                                            onDelete: (m) async {
                                                              await ChatHandlers.deleteMessage(
                                                                ctx,
                                                                widget
                                                                    .wsService,
                                                                m,
                                                              );
                                                            },
                                                          ),
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
                                                        (currentUser != null
                                                            ? (AvatarCacheService.getCachedAvatar(
                                                                    currentUser!
                                                                        .id,
                                                                  ) ??
                                                                  currentUser!
                                                                      .userImageUrl)
                                                            : '') ??
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
                                              label: ChatUtils.dateLabelFor(
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
                                        (ChatUtils.unreadDividerIndex(
                                                  _messages,
                                                  _lastReadAt,
                                                ) ==
                                                null
                                            ? 0
                                            : 1),
                                  ),
                                ),
                              ),
                              // Beginning of conversation header (pinned at top)
                              if (_hasReachedTop && _messages.isNotEmpty)
                                SliverPersistentHeader(
                                  pinned: true,
                                  delegate: BeginningHeaderDelegate(),
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
                                final dividerAt = ChatUtils.unreadDividerIndex(
                                  _messages,
                                  _lastReadAt,
                                );
                                if (dividerAt == null) {
                                  ConversationReadTracker.setLastReadToNow(
                                    widget.groupId,
                                  );
                                  _lastReadAt = DateTime.now();
                                }
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
                                onPressed: () => ChatHandlers.cancelReply(
                                  (replyingTo) =>
                                      setState(() => _replyingTo = replyingTo),
                                ),
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
                                onSubmitted: (_) => ChatHandlers.sendMessage(
                                  context,
                                  _messageController.text.trim(),
                                  widget.isReadOnly,
                                  _isSending,
                                  (sending) =>
                                      setState(() => _isSending = sending),
                                  _replyingTo,
                                  (replyingTo) =>
                                      setState(() => _replyingTo = replyingTo),
                                  widget.wsService,
                                  widget.groupId,
                                  _messages,
                                  (messages) =>
                                      setState(() => _messages = messages),
                                  _statusService,
                                  _messageController,
                                  (lastReadAt) =>
                                      setState(() => _lastReadAt = lastReadAt),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            CustomGlassButton(
                              onPressed: () => ChatHandlers.sendMessage(
                                context,
                                _messageController.text.trim(),
                                widget.isReadOnly,
                                _isSending,
                                (sending) =>
                                    setState(() => _isSending = sending),
                                _replyingTo,
                                (replyingTo) =>
                                    setState(() => _replyingTo = replyingTo),
                                widget.wsService,
                                widget.groupId,
                                _messages,
                                (messages) =>
                                    setState(() => _messages = messages),
                                _statusService,
                                _messageController,
                                (lastReadAt) =>
                                    setState(() => _lastReadAt = lastReadAt),
                              ),
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
