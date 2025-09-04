import 'package:flutter/material.dart';
import 'dart:async';
import '../models/user_models.dart';
import '../services/chat_services.dart';
import '../widgets/network_image.dart';

class ChatPage extends StatefulWidget {
  final String groupId;
  final String title;
  final WebSocketChatService wsService;
  final bool isReadOnly;

  const ChatPage({super.key, required this.groupId, required this.title, required this.wsService, this.isReadOnly = false});

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
      final loaded = await _apiService.fetchChatMessages(widget.groupId, currentUser!.chatToken);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load messages: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
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
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Be the first to start the conversation!',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final String currentSender = message.sender;
                          final String? previousSender = index > 0 ? _messages[index - 1].sender : null;
                          final bool isNewBlock = previousSender == null || previousSender != currentSender;
                          final bool showLeftAvatar = !message.isOwnMessage && isNewBlock;
                          final bool showRightAvatar = message.isOwnMessage && isNewBlock;
                          const double avatarSize = 32;
                          const double avatarGap = 8;
                          return Align(
                            alignment: message.isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
                            child: Row(
                              mainAxisAlignment: message.isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
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
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        child: Text(
                                          message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: avatarGap),
                                  ]
                                  else
                                    const SizedBox(width: avatarSize + avatarGap),
                                Flexible(
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: message.isOwnMessage
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: message.isOwnMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        if (!message.isOwnMessage && isNewBlock)
                                          Text(
                                            message.senderName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                        Text(
                                          message.message,
                                          style: TextStyle(
                                            color: message.isOwnMessage
                                                ? Theme.of(context).colorScheme.onPrimary
                                                : Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatTimestamp(message.timestamp),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: message.isOwnMessage
                                                ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)
                                                : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (message.isOwnMessage)
                                  if (showRightAvatar) ...[
                                    SizedBox(width: avatarGap),
                                    SafeNetworkImage(
                                      imageUrl: currentUser?.userImageUrl ?? '',
                                      width: avatarSize,
                                      height: avatarSize,
                                      errorWidget: CircleAvatar(
                                        radius: avatarSize / 2,
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        child: Text(
                                          (currentUser?.name.isNotEmpty ?? false) ? currentUser!.name[0].toUpperCase() : 'Y',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ]
                                  else
                                    const SizedBox(width: avatarGap + avatarSize),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          if (!widget.isReadOnly)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendMessage,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          if (widget.isReadOnly)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'This group is read-only',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


