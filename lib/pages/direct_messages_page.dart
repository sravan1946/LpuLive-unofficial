import 'package:flutter/material.dart';
import 'dart:async';
import '../models/user_models.dart';
import '../services/chat_services.dart';
import '../utils/timestamp_utils.dart';
import 'token_input_page.dart';
import 'new_dm_page.dart';

class DirectMessagesPage extends StatefulWidget {
  final WebSocketChatService wsService;

  const DirectMessagesPage({super.key, required this.wsService});

  @override
  State<DirectMessagesPage> createState() => _DirectMessagesPageState();
}

class _DirectMessagesPageState extends State<DirectMessagesPage> {
  final TextEditingController _messageController = TextEditingController();
  final ChatApiService _apiService = ChatApiService();
  late List<DirectMessage> _directMessages;
  DirectMessage? _selectedDM;
  List<ChatMessage> _dmMessages = [];
  bool _isLoadingDM = false;
  StreamSubscription<ChatMessage>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _systemMessageSubscription;

  @override
  void initState() {
    super.initState();
    _initializeDMs();
    _setupWebSocketSubscriptions();
  }

  void _handleSystemMessage(Map<String, dynamic> message) {
    if (message['type'] == 'force_disconnect') {
      debugPrint('🚪 [DirectMessagesPage] Force disconnect received');
      _handleForceDisconnect(message);
    }
  }

  void _handleForceDisconnect(Map<String, dynamic> message) async {
    debugPrint('🚪 [DirectMessagesPage] Handling force disconnect');

    // Disconnect WebSocket
    widget.wsService.disconnect();

    // Clear token
    await TokenStorage.clearToken();

    // Show notification
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message['message'] ?? 'You have been disconnected from another device.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );

      // Navigate to login after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const TokenInputApp(autoLoggedOut: true)),
            (route) => false,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageSubscription?.cancel();
    _systemMessageSubscription?.cancel();
    super.dispose();
  }

  void _initializeDMs() {
    if (currentUser != null) {
      _directMessages = [];
      final seenNames = <String>{};

      for (final group in currentUser!.groups) {
        final dmMatch = RegExp(r'^\d+\s*:\s*\d+$').firstMatch(group.name);
        if (dmMatch != null && !seenNames.contains(group.name)) {
          final dm = DirectMessage(
            dmName: group.name,
            participants: group.name,
            lastMessage: group.groupLastMessage,
            lastMessageTime: group.lastMessageTime,
            isActive: group.isActive,
            isAdmin: group.isAdmin,
          );
          _directMessages.add(dm);
          seenNames.add(group.name);
        }
      }

      _sortDirectMessages();
    } else {
      _directMessages = [];
    }
  }

  void _sortDirectMessages() {
    _directMessages.sort((a, b) {
      // Parse timestamps, handling empty strings and invalid formats
      DateTime? timeA = _parseTimestamp(a.lastMessageTime);
      DateTime? timeB = _parseTimestamp(b.lastMessageTime);

      // Primary sort: by timestamp (most recent first)
      // Groups with timestamps come before groups without timestamps
      if (timeA != null && timeB != null) {
        // Both have timestamps - compare them (most recent first)
        return timeB.compareTo(timeA);
      } else if (timeA != null && timeB == null) {
        // A has timestamp, B doesn't - A comes first
        return -1;
      } else if (timeA == null && timeB != null) {
        // B has timestamp, A doesn't - B comes first
        return 1;
      } else {
        // Both don't have timestamps - fall through to secondary sort
        // Secondary sort: by name (alphabetical) - for groups without timestamps
        return a.dmName.compareTo(b.dmName);
      }
    });
  }

  DateTime? _parseTimestamp(String timestamp) {
    return TimestampUtils.parseTimestamp(timestamp);
  }

  void _setupWebSocketSubscriptions() {
    _messageSubscription = widget.wsService.messageStream.listen((message) {
      _handleNewMessage(message);
    });

    _systemMessageSubscription = widget.wsService.systemMessageStream.listen((message) {
      _handleSystemMessage(message);
    });
  }

  void _handleNewMessage(ChatMessage message) {
    setState(() {
      final dmIndex = _directMessages.indexWhere((dm) => dm.dmName == message.sender);
      if (dmIndex != -1) {
        // If this message belongs to the currently selected DM, add it to the messages
        if (_selectedDM != null && _selectedDM!.dmName == message.sender) {
          final updatedMessages = [..._dmMessages, message];

          // Sort messages by timestamp to maintain chronological order
          updatedMessages.sort((a, b) {
            try {
              final dateA = DateTime.parse(a.timestamp);
              final dateB = DateTime.parse(b.timestamp);
              return dateA.compareTo(dateB);
            } catch (e) {
              return 0;
            }
          });

          _dmMessages = updatedMessages;
        }

        // Update the group's last message in the token
        if (currentUser != null) {
          for (int i = 0; i < currentUser!.groups.length; i++) {
            if (currentUser!.groups[i].name == message.sender) {
              currentUser!.groups[i] = currentUser!.groups[i].copyWith(
                groupLastMessage: message.message,
                lastMessageTime: message.timestamp,
              );
              // Also update the corresponding DirectMessage
              final dmIndex = _directMessages.indexWhere((dm) => dm.dmName == message.sender);
              if (dmIndex != -1) {
                _directMessages[dmIndex] = _directMessages[dmIndex].copyWith(
                  lastMessage: message.message,
                  lastMessageTime: message.timestamp,
                );
              }
            }
          }
        }
        }

        // Save updated user data to token storage
        TokenStorage.saveCurrentUser();
      });

    // Sort after setState completes to ensure proper re-rendering
    _sortDirectMessages();
  }

  Future<void> _selectDM(DirectMessage dm) async {
    setState(() {
      _selectedDM = dm;
      _isLoadingDM = true;
      _dmMessages = [];
    });

    try {
      final messages = await _apiService.fetchChatMessages(dm.dmName, currentUser!.chatToken);
      setState(() {
        _dmMessages = messages;
        _isLoadingDM = false;
      });

      // Update the group's last message in the token if messages were loaded
      if (messages.isNotEmpty && currentUser != null) {
        final lastMsg = messages.last;
        for (int i = 0; i < currentUser!.groups.length; i++) {
          if (currentUser!.groups[i].name == dm.dmName) {
            currentUser!.groups[i] = currentUser!.groups[i].copyWith(
              groupLastMessage: lastMsg.message,
              lastMessageTime: lastMsg.timestamp,
            );
            // Also update the corresponding DirectMessage
            final dmIndex = _directMessages.indexWhere((d) => d.dmName == dm.dmName);
            if (dmIndex != -1) {
              _directMessages[dmIndex] = _directMessages[dmIndex].copyWith(
                lastMessage: lastMsg.message,
                lastMessageTime: lastMsg.timestamp,
              );
            }
          }
        }
        _sortDirectMessages(); // Re-sort after updating timestamps

        // Save updated user data to token storage
        TokenStorage.saveCurrentUser();
      }
    } catch (e) {
      setState(() {
        _isLoadingDM = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load DM messages: $e')),
        );
      }
    }
  }

  Future<void> _startNewDM() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const NewDMPage()),
    );

    // If a new DM was created successfully, refresh the DM list
    if (result == true) {
      _initializeDMs();
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    if (!widget.wsService.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not connected to chat server')),
        );
      }
      return;
    }

    if (_selectedDM == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a DM first')),
        );
      }
      return;
    }

    try {
      final groupId = _selectedDM!.dmName;

      await widget.wsService.sendMessage(
        message: message,
        group: groupId,
      );

      // Update the group's last message in the token
      if (currentUser != null) {
        final timestamp = DateTime.now().toIso8601String();
        for (int i = 0; i < currentUser!.groups.length; i++) {
          if (currentUser!.groups[i].name == groupId) {
            currentUser!.groups[i] = currentUser!.groups[i].copyWith(
              groupLastMessage: message,
              lastMessageTime: timestamp,
            );
            // Also update the corresponding DirectMessage
            final dmIndex = _directMessages.indexWhere((dm) => dm.dmName == groupId);
            if (dmIndex != -1) {
              _directMessages[dmIndex] = _directMessages[dmIndex].copyWith(
                lastMessage: message,
                lastMessageTime: timestamp,
              );
            }
          }
        }
        _sortDirectMessages(); // Re-sort after updating timestamps
      }

      // Save updated user data to token storage
      await TokenStorage.saveCurrentUser();

      setState(() {}); // Trigger rebuild to update the list with new last message

      _messageController.clear();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedDM != null) {
          setState(() {
            _selectedDM = null;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(_selectedDM != null
              ? 'DM: ${_selectedDM!.participants}'
              : 'Direct Messages'),
          leading: _selectedDM != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _selectedDM = null;
                    });
                  },
                  tooltip: 'Back to DM selection',
                )
              : null,
        ),
        body: _selectedDM == null
            ? _buildDMList()
            : _buildDMChat(),
      ),
    );
  }

  Widget _buildDMList() {
    if (_directMessages.isEmpty) {
      return Stack(
        children: [
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.message, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No Direct Messages',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Direct messages will appear here',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _startNewDM,
              tooltip: 'Start New DM',
              child: const Icon(Icons.add),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _directMessages.length,
          itemBuilder: (context, index) {
            final dm = _directMessages[index];

        return Card(
          key: ValueKey(dm.dmName),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                title: Text('DM: ${dm.participants}'),
                subtitle: Text(
                  dm.lastMessage.isNotEmpty ? dm.lastMessage : 'No messages yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      dm.lastMessageTime.isNotEmpty
                          ? _formatTimestamp(dm.lastMessageTime)
                          : '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (dm.isAdmin)
                      const Icon(Icons.admin_panel_settings, color: Colors.orange, size: 16),
                  ],
                ),
                onTap: () => _selectDM(dm),
              ),
            );
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _startNewDM,
            tooltip: 'Start New DM',
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildDMChat() {
    return Column(
      children: [
        Expanded(
          child: _isLoadingDM
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading DM messages...'),
                    ],
                  ),
                )
              : _dmMessages.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.message, size: 64, color: Colors.grey),
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
                      itemCount: _dmMessages.length,
                      itemBuilder: (context, index) {
                        final message = _dmMessages[index];
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
                              if (!message.isOwnMessage) ...[
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  child: Text(
                                    message.senderName.isNotEmpty
                                        ? message.senderName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
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
                                    crossAxisAlignment: message.isOwnMessage
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      if (!message.isOwnMessage)
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
                              if (message.isOwnMessage) ...[
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  child: Text(
                                    currentUser?.name.isNotEmpty ?? false
                                        ? currentUser!.name[0].toUpperCase()
                                        : 'Y',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
        ),

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
      ],
    );
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
}