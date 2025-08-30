import 'package:flutter/material.dart';
import 'dart:async';
import '../models/user_models.dart';
import '../services/chat_services.dart';
import '../widgets/network_image.dart';
import 'token_input_page.dart';

class UniversityGroupsPage extends StatefulWidget {
  const UniversityGroupsPage({super.key});

  @override
  State<UniversityGroupsPage> createState() => _UniversityGroupsPageState();
}

class _UniversityGroupsPageState extends State<UniversityGroupsPage> {
  final TextEditingController _messageController = TextEditingController();
  final ChatApiService _apiService = ChatApiService();
  final WebSocketChatService _wsService = WebSocketChatService();
  late List<CourseGroup> _courseGroups;
  CourseGroup? _selectedCourse;
  StreamSubscription<ChatMessage>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _initializeGroups();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageSubscription?.cancel();
    _wsService.disconnect();
    super.dispose();
  }

  void _initializeGroups() {
    if (currentUser != null) {
      _courseGroups = [];

      for (final group in currentUser!.groups) {
        final courseMatch = RegExp(r'^([A-Z]+\d+)\s*-\s*([A-Z]+\d+)$').firstMatch(group.name);
        if (courseMatch != null) {
          final courseCode = courseMatch.group(1)!;
          final courseGroup = CourseGroup(
            courseName: group.name,
            courseCode: courseCode,
            messages: [],
          );
          _courseGroups.add(courseGroup);
        }
      }
    } else {
      _courseGroups = [];
    }
  }

  Future<void> _connectWebSocket() async {
    if (currentUser != null) {
      try {
        await _wsService.connect(currentUser!.chatToken);

        _messageSubscription = _wsService.messageStream.listen((message) {
          _handleNewMessage(message);
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to connect to chat server: $e')),
          );
        }
      }
    }
  }

  void _handleNewMessage(ChatMessage message) {
    setState(() {
      final courseIndex = _courseGroups.indexWhere((course) => course.courseName == message.sender);
      if (courseIndex != -1) {
        final course = _courseGroups[courseIndex];
        final updatedMessages = [...course.messages, message];

        updatedMessages.sort((a, b) {
          try {
            final dateA = DateTime.parse(a.timestamp);
            final dateB = DateTime.parse(b.timestamp);
            return dateA.compareTo(dateB);
          } catch (e) {
            return 0;
          }
        });

        _courseGroups[courseIndex] = course.copyWith(messages: updatedMessages);

        if (_selectedCourse?.courseCode == course.courseCode) {
          _selectedCourse = course.copyWith(messages: updatedMessages);
        }
      }
    });
  }

  Future<void> _loadCourseMessages(CourseGroup course) async {
    if (currentUser == null) return;

    setState(() {
      _selectedCourse = course.copyWith(isLoading: true);
      final index = _courseGroups.indexWhere((c) => c.courseCode == course.courseCode);
      if (index != -1) {
        _courseGroups[index] = course.copyWith(isLoading: true);
      }
    });

    try {
      final messages = await _apiService.fetchChatMessages(
        course.courseName,
        currentUser!.chatToken,
      );

      setState(() {
        final index = _courseGroups.indexWhere((c) => c.courseCode == course.courseCode);
        if (index != -1) {
          _courseGroups[index] = course.copyWith(
            messages: messages,
            isLoading: false,
          );
        }
        _selectedCourse = course.copyWith(
          messages: messages,
          isLoading: false,
        );
      });
    } catch (e) {
      setState(() {
        final index = _courseGroups.indexWhere((c) => c.courseCode == course.courseCode);
        if (index != -1) {
          _courseGroups[index] = course.copyWith(isLoading: false);
        }
        _selectedCourse = course.copyWith(isLoading: false);
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
    if (message.isEmpty) return;

    if (!_wsService.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not connected to chat server')),
        );
      }
      return;
    }

    if (_selectedCourse == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a course first')),
        );
      }
      return;
    }

    try {
      final groupId = _selectedCourse!.courseName;

      await _wsService.sendMessage(
        message: message,
        group: groupId,
      );

      _messageController.clear();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  bool _isGroupWritable(CourseGroup course) {
    final originalGroup = currentUser?.groups.firstWhere(
      (group) => group.name == course.courseName,
      orElse: () => Group(
        name: course.courseName,
        groupLastMessage: '',
        lastMessageTime: '',
        isActive: false,
        isAdmin: false,
        inviteStatus: '',
        isTwoWay: false,
        isOneToOne: false,
      ),
    );

    return originalGroup!.isActive &&
           (originalGroup.isTwoWay || originalGroup.isAdmin);
  }

  void _showUserInfo() {
    if (currentUser == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Name', currentUser!.name),
              _buildInfoRow('Display Name', currentUser!.displayName),
              _buildInfoRow('Registration Number', currentUser!.id),
              _buildInfoRow('Department', currentUser!.department),
              _buildInfoRow('Category', currentUser!.category),
              _buildInfoRow('Groups', '${currentUser!.groups.length} groups'),
              _buildInfoRow('Can Create Groups', currentUser!.createGroups ? 'Yes' : 'No'),
              _buildInfoRow('One-to-One Chat', currentUser!.oneToOne ? 'Enabled' : 'Disabled'),
              _buildInfoRow('Chat Suspended', currentUser!.isChatSuspended ? 'Yes' : 'No'),
              if (currentUser!.userImageUrl != null)
                _buildInfoRow('Profile Image', currentUser!.userImageUrl!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14)),
          const Divider(),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedCourse != null) {
          setState(() {
            _selectedCourse = null;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(_selectedCourse != null
              ? _selectedCourse!.courseName.replaceFirst(RegExp(r'^[A-Z]+\d+\s*-\s*'), '')
              : 'University Groups'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: _showUserInfo,
              tooltip: 'User Info',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout') {
                  _logout();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
            ),
          ],
          leading: _selectedCourse != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _selectedCourse = null;
                    });
                  },
                  tooltip: 'Back to course selection',
                )
              : null,
        ),
        body: _selectedCourse == null
            ? _buildCourseList()
            : Column(
                children: [
                  Expanded(
                    child: _selectedCourse!.isLoading
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Loading course messages...'),
                              ],
                            ),
                          )
                        : _selectedCourse!.messages.isEmpty
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
                                itemCount: _selectedCourse!.messages.length,
                                itemBuilder: (context, index) {
                                  final message = _selectedCourse!.messages[index];
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
                                          SafeNetworkImage(
                                            imageUrl: message.userImage ?? '',
                                            width: 32,
                                            height: 32,
                                            errorWidget: CircleAvatar(
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
                                          SafeNetworkImage(
                                            imageUrl: currentUser?.userImageUrl ?? '',
                                            width: 32,
                                            height: 32,
                                            errorWidget: CircleAvatar(
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
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),

                  if (_selectedCourse != null && _isGroupWritable(_selectedCourse!))
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
                              decoration: InputDecoration(
                                hintText: 'Type a message in ${_selectedCourse!.courseCode}...',
                                border: const OutlineInputBorder(),
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
                    )
                  else if (_selectedCourse != null && !_isGroupWritable(_selectedCourse!))
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
      ),
    );
  }

  Widget _buildCourseList() {
    if (_courseGroups.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No University Courses',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'University courses will appear here',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _courseGroups.length,
      itemBuilder: (context, index) {
        final course = _courseGroups[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.school, color: Colors.white),
            ),
            title: Text(course.courseName),
            subtitle: Text(
              course.messages.isNotEmpty
                  ? course.messages.last.message
                  : 'No messages yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isGroupWritable(course))
                      Icon(
                        Icons.visibility,
                        size: 14,
                        color: Colors.orange,
                      ),
                    const SizedBox(width: 4),
                    Text(
                      course.messages.isNotEmpty
                          ? _formatTimestamp(course.messages.last.timestamp)
                          : '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (course.messages.isNotEmpty && course.messages.last.isOwnMessage)
                  Icon(
                    Icons.done_all,
                    size: 16,
                    color: Colors.blue,
                  ),
              ],
            ),
            onTap: () => _loadCourseMessages(course),
          ),
        );
      },
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout? This will require you to enter your token again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              await TokenStorage.clearToken();
              currentUser = null;
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const TokenInputApp()),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}