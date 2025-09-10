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
  late List<CourseGroup> _courseGroups;
  CourseGroup? _selectedCourse;
  StreamSubscription<ChatMessage>? _messageSubscription;
  String _query = '';

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
        final courseMatch = RegExp(
          r'^([A-Z]+\d+)\s*-\s*([A-Z]+\d+)$',
        ).firstMatch(group.name);
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
        _courseGroups[index] = course.copyWith(
          lastMessageTime: message.timestamp,
        );
        _sortCourseGroups();
        setState(() {});
      }
    });
  }

  Future<void> _openCourseChat(CourseGroup course) async {
    final isWritable = _isGroupWritable(course);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatPage(
          groupId: course.courseName,
          title: course.courseName.replaceFirst(
            RegExp(r'^[A-Z]+\d+\s*-\s*'),
            '',
          ),
          wsService: widget.wsService,
          isReadOnly: !isWritable,
        ),
      ),
    );
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
              if (currentUser!.userImageUrl != null &&
                  currentUser!.userImageUrl!.isNotEmpty) ...[
                Center(
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: ClipOval(
                      child: SafeNetworkImage(
                        imageUrl: currentUser!.userImageUrl!,
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                        highQuality: true,
                        errorWidget: Center(
                          child: Text(
                            currentUser!.displayName.isNotEmpty
                                ? currentUser!.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _buildInfoRow('Name', currentUser!.name),
              _buildInfoRow('Display Name', currentUser!.displayName),
              _buildInfoRow('Registration Number', currentUser!.id),
              _buildInfoRow('Department', currentUser!.department),
              _buildInfoRow('Category', currentUser!.category),
              _buildInfoRow('Groups', '${currentUser!.groups.length} groups'),
              _buildInfoRow(
                'Can Create Groups',
                currentUser!.createGroups ? 'Yes' : 'No',
              ),
              _buildInfoRow(
                'One-to-One Chat',
                currentUser!.oneToOne ? 'Enabled' : 'Disabled',
              ),
              _buildInfoRow(
                'Chat Suspended',
                currentUser!.isChatSuspended ? 'Yes' : 'No',
              ),
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
    final scheme = Theme.of(context).colorScheme;
    final filtered = _courseGroups
        .where(
          (c) =>
              _query.isEmpty ||
              c.courseName.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_selectedCourse != null) {
          setState(() {
            _selectedCourse = null;
          });
          return;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _selectedCourse != null
                ? _selectedCourse!.courseName.replaceFirst(
                    RegExp(r'^[A-Z]+\d+\s*-\s*'),
                    '',
                  )
                : 'University Groups',
          ),
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
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SearchBar(
                leading: const Icon(Icons.search),
                hintText: 'Search courses',
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildCourseList(filtered, scheme)),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseList(List<CourseGroup> data, ColorScheme scheme) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'No University Courses',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'University courses will appear here',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final course = data[index];
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

        final lastMessage = group!.groupLastMessage.isNotEmpty
            ? group.groupLastMessage
            : 'No messages yet';
        final lastMessageTime = course.lastMessageTime.isNotEmpty
            ? course.lastMessageTime
            : '';
        final readOnly = !_isGroupWritable(course);

        return Card(
          key: ValueKey(course.courseName),
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.primary,
              child: const Icon(Icons.school, color: Colors.white),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    course.courseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
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
                    if (readOnly)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    Text(
                      lastMessageTime.isNotEmpty
                          ? _formatTimestamp(lastMessageTime)
                          : '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (course.messages.isNotEmpty &&
                    course.messages.last.isOwnMessage)
                  Icon(Icons.done_all, size: 16, color: scheme.primary),
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
        content: const Text(
          'Are you sure you want to logout? This will require you to enter your token again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop();
              await TokenStorage.clearToken();
              currentUser = null;
              navigator.pushReplacement(
                MaterialPageRoute(builder: (context) => const TokenInputApp()),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
