import 'package:flutter/material.dart';
import 'dart:async';
import '../models/user_models.dart';
import '../services/chat_services.dart';
import '../widgets/network_image.dart';
import '../utils/timestamp_utils.dart';
import 'token_input_page.dart';
import 'chat_page.dart';

class UniversityGroupsPage extends StatefulWidget {
  final WebSocketChatService wsService;

  const UniversityGroupsPage({super.key, required this.wsService});

  @override
  State<UniversityGroupsPage> createState() => _UniversityGroupsPageState();
}

class _UniversityGroupsPageState extends State<UniversityGroupsPage> {
  final TextEditingController _messageController = TextEditingController();
  final ChatApiService _apiService = ChatApiService();
  late List<CourseGroup> _courseGroups;
  CourseGroup? _selectedCourse;
  StreamSubscription<ChatMessage>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _initializeGroups();
    _setupWebSocketSubscription();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageSubscription?.cancel();
    super.dispose();
  }

  void _initializeGroups() {
    if (currentUser != null) {
      _courseGroups = [];
      final seenNames = <String>{};

      for (final group in currentUser!.groups) {
        final courseMatch = RegExp(r'^([A-Z]+\d+)\s*-\s*([A-Z]+\d+)$').firstMatch(group.name);
        if (courseMatch != null && !seenNames.contains(group.name)) {
          final courseCode = courseMatch.group(1)!;
          final courseGroup = CourseGroup(
            courseName: group.name,
            courseCode: courseCode,
            messages: [],
            lastMessageTime: group.lastMessageTime,
          );
          _courseGroups.add(courseGroup);
          seenNames.add(group.name);
        }
      }

      _sortCourseGroups();
    } else {
      _courseGroups = [];
    }
  }

  void _sortCourseGroups() {
    _courseGroups.sort((a, b) {
      final DateTime? timeA = _parseTimestamp(a.lastMessageTime);
      final DateTime? timeB = _parseTimestamp(b.lastMessageTime);

      final hasTimeA = timeA != null;
      final hasTimeB = timeB != null;

      // Put items with time first
      if (hasTimeA != hasTimeB) {
        return hasTimeA ? -1 : 1; // true before false
      }

      // If both have time, sort by time desc (most recent first)
      if (hasTimeA && hasTimeB) {
        return timeB.compareTo(timeA);
      }

      // If both have no time, sort by name asc
      return a.courseName.compareTo(b.courseName);
    });
  }

  DateTime? _parseTimestamp(String timestamp) {
    return TimestampUtils.parseTimestamp(timestamp);
  }

  void _setupWebSocketSubscription() {
    _messageSubscription = widget.wsService.messageStream.listen((message) {
      // Update cached last message time for list and re-sort
      final targetName = (message.group != null && message.group!.isNotEmpty)
          ? message.group!
          : message.sender;
      final index = _courseGroups.indexWhere((c) => c.courseName == targetName);
      if (index != -1) {
        final course = _courseGroups[index];
        _courseGroups[index] = course.copyWith(lastMessageTime: message.timestamp);
        _sortCourseGroups();
        setState(() {});
      }
    });
  }

  void _handleNewMessage(ChatMessage message) {
    setState(() {
      final courseIndex = _courseGroups.indexWhere((course) => course.courseName == message.group);
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

        // Update the group's last message in the token
        if (currentUser != null) {
          for (int i = 0; i < currentUser!.groups.length; i++) {
            if (currentUser!.groups[i].name == message.group) {
              currentUser!.groups[i] = currentUser!.groups[i].copyWith(
                groupLastMessage: message.message,
                lastMessageTime: message.timestamp,
              );
              // Also update the corresponding CourseGroup
              final courseIndex = _courseGroups.indexWhere((course) => course.courseName == message.group);
              if (courseIndex != -1) {
                _courseGroups[courseIndex] = _courseGroups[courseIndex].copyWith(
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
    _sortCourseGroups();
  }

  Future<void> _openCourseChat(CourseGroup course) async {
    final isWritable = _isGroupWritable(course);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatPage(
          groupId: course.courseName,
          title: course.courseName.replaceFirst(RegExp(r'^[A-Z]+\d+\s*-\s*'), ''),
          wsService: widget.wsService,
          isReadOnly: !isWritable,
        ),
      ),
    );
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
            // Also update the corresponding CourseGroup
            final courseIndex = _courseGroups.indexWhere((course) => course.courseName == groupId);
            if (courseIndex != -1) {
              _courseGroups[courseIndex] = _courseGroups[courseIndex].copyWith(
                lastMessageTime: timestamp,
              );
            }
          }
        }
        _sortCourseGroups(); // Re-sort after updating timestamps
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
        body: _buildCourseList(),
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
        final group = currentUser?.groups.firstWhere(
          (g) => g.name == course.courseName,
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

        final lastMessage = group!.groupLastMessage.isNotEmpty ? group.groupLastMessage : 'No messages yet';
        final lastMessageTime = course.lastMessageTime.isNotEmpty ? course.lastMessageTime : '';

        return Card(
          key: ValueKey(course.courseName),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.school, color: Colors.white),
            ),
            title: Text(course.courseName),
            subtitle: Text(
              lastMessage,
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
                      lastMessageTime.isNotEmpty
                          ? _formatTimestamp(lastMessageTime)
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
            onTap: () => _openCourseChat(course),
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