import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:animations/animations.dart';
import 'dart:async';
import '../models/user_models.dart';
import '../services/chat_services.dart';
import '../utils/timestamp_utils.dart';
import 'chat_page.dart';
import '../services/read_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'profile_page.dart';

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

  // Unread counters per course group
  final Map<String, int> _unreadByGroup = {};
  final ChatApiService _apiService = ChatApiService();
  static const String _kUnreadUniKey = 'unread_uni_counts_v1';

  Future<void> _loadUnreadCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kUnreadUniKey);
      if (raw == null || raw.isEmpty) return;
      final Map<String, dynamic> m = jsonDecode(raw);
      _unreadByGroup.clear();
      final existing = _courseGroups.map((c) => c.courseName).toSet();
      for (final e in m.entries) {
        final k = e.key;
        final v = int.tryParse(e.value.toString()) ?? 0;
        if (existing.contains(k) && v > 0) {
          _unreadByGroup[k] = v;
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _saveUnreadCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUnreadUniKey, jsonEncode(_unreadByGroup));
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _initializeGroups();
    _setupWebSocketSubscription();
    _loadUnreadCounts();
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
          _unreadByGroup.putIfAbsent(group.name, () => 0);
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

  String _stripCourseCodePrefix(String name) {
    return name.replaceFirst(RegExp(r'^[A-Z]+\d+\s*-\s*'), '').trim();
  }

  int _indexForIncomingMessage(ChatMessage message) {
    final incomingGroup = (message.group ?? '').trim();
    if (incomingGroup.isEmpty) return -1;
    final normalizedIncoming = _stripCourseCodePrefix(
      incomingGroup,
    ).toLowerCase();
    return _courseGroups.indexWhere((c) {
      final full = c.courseName;
      final normalized = _stripCourseCodePrefix(full).toLowerCase();
      return full == incomingGroup ||
          normalized == normalizedIncoming ||
          full.toLowerCase() == incomingGroup.toLowerCase();
    });
  }

  void _setupWebSocketSubscription() {
    _messageSubscription = widget.wsService.messageStream.listen((message) {
      final index = _indexForIncomingMessage(message);
      if (index != -1) {
        final course = _courseGroups[index];
        final groupKey = course.courseName;
        _courseGroups[index] = course.copyWith(
          lastMessageTime: message.timestamp,
        );
        if (!message.isOwnMessage && !OpenConversations.isOpen(groupKey)) {
          _unreadByGroup.update(groupKey, (v) => v + 1, ifAbsent: () => 1);
          _saveUnreadCounts();
        }
        _sortCourseGroups();
        setState(() {});
      }
    });
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
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Text(
                  _selectedCourse != null
                      ? _selectedCourse!.courseName.replaceFirst(
                          RegExp(r'^[A-Z]+\d+\s*-\s*'),
                          '',
                        )
                      : 'University Groups',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                },
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: scheme.surfaceContainerHighest,
                  foregroundColor: scheme.onSurface,
                  child: (currentUser?.userImageUrl != null &&
                          currentUser!.userImageUrl!.isNotEmpty)
                      ? ClipOval(
                          child: Image.network(
                            currentUser!.userImageUrl!,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.person, size: 18);
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Icon(Icons.person, size: 18);
                            },
                          ),
                        )
                      : const Icon(Icons.person, size: 18),
                ),
              ),
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
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshCourses,
                child: _buildCourseList(filtered, scheme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshCourses() async {
    if (currentUser == null) return;
    try {
      for (final course in _courseGroups) {
        try {
          final msgs = await _apiService.fetchChatMessages(
            course.courseName,
            currentUser!.chatToken,
          );
          if (msgs.isNotEmpty) {
            final latest = msgs.last;
            final idx = _courseGroups.indexWhere(
              (c) => c.courseName == course.courseName,
            );
            if (idx != -1) {
              _courseGroups[idx] = _courseGroups[idx].copyWith(
                lastMessageTime: latest.timestamp,
              );
            }
            for (int i = 0; i < currentUser!.groups.length; i++) {
              if (currentUser!.groups[i].name == course.courseName) {
                currentUser!.groups[i] = currentUser!.groups[i].copyWith(
                  groupLastMessage: latest.message,
                  lastMessageTime: latest.timestamp,
                );
              }
            }
          }
        } catch (_) {
          // ignore individual failures
        }
      }
      _sortCourseGroups();
      await TokenStorage.saveCurrentUser();
      await _saveUnreadCounts();
    } finally {
    }
  }

  Widget _buildCourseList(List<CourseGroup> data, ColorScheme scheme) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            SpinKitPulse(color: scheme.primary, size: 28),
            const SizedBox(height: 12),
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
      physics: const AlwaysScrollableScrollPhysics(),
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
        final unread = _unreadByGroup[course.courseName] ?? 0;
        final hasUnread = unread > 0;

        return OpenContainer(
          transitionType: ContainerTransitionType.fadeThrough,
          closedElevation: 1,
          openElevation: 0,
          closedColor: Theme.of(context).colorScheme.surface,
          closedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          openBuilder: (context, _) {
            // Clear unread when opening
            _unreadByGroup[course.courseName] = 0;
            _saveUnreadCounts();
            ConversationReadTracker.setLastReadToNow(course.courseName);
            final isWritable = _isGroupWritable(course);
            return ChatPage(
              groupId: course.courseName,
              title: course.courseName.replaceFirst(
                RegExp(r'^[A-Z]+\d+\s*-\s*'),
                '',
              ),
              wsService: widget.wsService,
              isReadOnly: !isWritable,
            );
          },
          closedBuilder: (context, openContainer) {
            return InkWell(
              onTap: () {
                setState(() {
                  _unreadByGroup[course.courseName] = 0;
                });
                _saveUnreadCounts();
                openContainer();
              },
              borderRadius: BorderRadius.circular(12),
              child: Card(
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
                          style: hasUnread
                              ? const TextStyle(fontWeight: FontWeight.w700)
                              : null,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: hasUnread
                        ? const TextStyle(fontWeight: FontWeight.w600)
                        : null,
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
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          Text(
                            lastMessageTime.isNotEmpty
                                ? _formatTimestamp(lastMessageTime)
                                : '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (hasUnread) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      if (course.messages.isNotEmpty &&
                          course.messages.last.isOwnMessage)
                        Icon(Icons.done_all, size: 16, color: scheme.primary),
                    ],
                  ),
                ),
              ),
            );
          },
        )
            .animate(delay: (40 * index).ms)
            .fadeIn(duration: 300.ms, curve: Curves.easeOut)
            .moveY(begin: 8, end: 0, duration: 300.ms, curve: Curves.easeOut);
      },
    );
  }
}
