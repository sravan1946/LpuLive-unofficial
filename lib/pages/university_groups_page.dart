// Dart imports:
import 'dart:async';
import 'dart:convert';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:animations/animations.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import '../models/current_user_state.dart';
import '../models/user_models.dart';
import '../services/chat_services.dart';
import '../services/read_tracker.dart';
import '../utils/timestamp_utils.dart';
import '../widgets/app_toast.dart';
import 'chat_page.dart';
import 'token_input_page.dart';

// profile/settings actions removed; use drawer instead
// Drawer lives at parent Scaffold; this page should not define its own drawer

class UniversityGroupsPage extends StatefulWidget {
  final WebSocketChatService wsService;
  final VoidCallback? onOpenDrawer;

  const UniversityGroupsPage({
    super.key,
    required this.wsService,
    this.onOpenDrawer,
  });

  @override
  State<UniversityGroupsPage> createState() => _UniversityGroupsPageState();
}

class _UniversityGroupsPageState extends State<UniversityGroupsPage> {
  final TextEditingController _messageController = TextEditingController();
  late List<CourseGroup> _courseGroups;
  CourseGroup? _selectedCourse;
  StreamSubscription<ChatMessage>? _messageSubscription;
  String _query = '';
  late final VoidCallback _userListener;

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

    // Listen for user data changes (e.g., when groups are updated)
    _userListener = () {
      if (!mounted) return;
      _initializeGroups();
      setState(() {});
    };
    currentUserNotifier.addListener(_userListener);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageSubscription?.cancel();
    currentUserNotifier.removeListener(_userListener);
    super.dispose();
  }

  void _initializeGroups() {
    if (currentUser != null) {
      _courseGroups = [];
      final seenNames = <String>{};

      for (final group in currentUser!.groups) {
        final isUni = !group.isTwoWay && !group.isOneToOne;
        if (isUni && !seenNames.contains(group.name)) {
          // Try to extract a course code prefix if present for display; fallback to name
          final codeMatch = RegExp(r'^[A-Z]+\d+').firstMatch(group.name);
          final courseCode = codeMatch?.group(0) ?? group.name;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          centerTitle: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
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
              : IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    debugPrint('🫓 UniversityGroupsPage hamburger tapped');
                    widget.onOpenDrawer?.call();
                  },
                  tooltip: 'Menu',
                ),
          title: Text(
            _selectedCourse != null
                ? _selectedCourse!.courseName.replaceFirst(
                    RegExp(r'^[A-Z]+\d+\s*-\s*'),
                    '',
                  )
                : 'University Groups',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1B1B1B),
            ),
          ),
          actions: const [],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF121212),
                      const Color(0xFF1E1E1E),
                      const Color(0xFF2A1A10),
                    ]
                  : [
                      const Color(0xFFF8F9FA),
                      const Color(0xFFFFF5F0),
                      const Color(0xFFFFE9D6),
                    ],
            ),
          ),
          child: Column(
            children: [
              // Enhanced search bar with gradient background
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF2A2A2A), const Color(0xFF1E1E1E)]
                        : [Colors.white, const Color(0xFFF8F9FA)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SearchBar(
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 4, right: 2),
                    child: Icon(Icons.search, size: 20, color: scheme.primary),
                  ),
                  hintText: 'Search courses',
                  onChanged: (v) => setState(() => _query = v),
                  backgroundColor: WidgetStateProperty.all(Colors.transparent),
                  elevation: WidgetStateProperty.all(0),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshCourses,
                  color: scheme.primary,
                  child: _buildCourseList(filtered, scheme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshCourses() async {
    if (currentUser == null) return;
    try {
      // First, refresh user data with authorize endpoint
      try {
        debugPrint(
          '🔄 [UniversityGroupsPage] Refreshing user data via authorize endpoint...',
        );
        final updatedUser = await _apiService.authorizeUser(
          currentUser!.chatToken,
        );
        setCurrentUser(updatedUser);
        await TokenStorage.saveCurrentUser();
        debugPrint('✅ [UniversityGroupsPage] User data refreshed successfully');
      } catch (e) {
        if (e is UnauthorizedException) {
          debugPrint(
            '❌ [UniversityGroupsPage] User unauthorized, logging out...',
          );
          await TokenStorage.clearToken();
          setCurrentUser(null);
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const UnifiedLoginScreen(autoLoggedOut: true),
              ),
            );
          }
          return;
        } else if (e is NetworkException) {
          debugPrint(
            '🌐 [UniversityGroupsPage] Network error during refresh: $e',
          );
          if (mounted) {
            showAppToast(
              context,
              'No internet connection. Please check your network and try again.',
              type: ToastType.error,
              duration: const Duration(seconds: 3),
            );
          }
          return;
        }
        debugPrint('⚠️ [UniversityGroupsPage] Failed to refresh user data: $e');
        // Continue with refresh even if authorize fails for other errors
      }

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
            // Note: currentUser groups are already updated by authorize endpoint
          }
        } catch (_) {
          // ignore individual failures
        }
      }
      _sortCourseGroups();
      await _saveUnreadCounts();
    } finally {}
  }

  Widget _buildCourseList(List<CourseGroup> data, ColorScheme scheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary.withValues(alpha: 0.1),
                    scheme.primary.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Icon(
                Icons.school_outlined,
                size: 64,
                color: scheme.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            SpinKitPulse(color: scheme.primary, size: 32),
            const SizedBox(height: 16),
            Text(
              'No University Courses',
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF5A5A5A),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'University courses will appear here',
              style: TextStyle(
                color: isDark ? Colors.white54 : const Color(0xFF8A8A8A),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
              closedElevation: 0,
              openElevation: 0,
              closedColor: Colors.transparent,
              closedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
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
                return TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 120),
                  tween: Tween(begin: 1.0, end: 1.0),
                  builder: (context, scale, child) {
                    return MouseRegion(
                      onEnter: (_) => setState(() {}),
                      onExit: (_) => setState(() {}),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 120),
                        scale: MediaQuery.of(context).size.width > 600
                            ? 1.02
                            : 1.0,
                        curve: Curves.easeOut,
                        child: child!,
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [const Color(0xFF2A2A2A), const Color(0xFF1E1E1E)]
                            : [Colors.white, const Color(0xFFFAFAFA)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.2)
                              : Colors.black.withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF333333)
                            : const Color(0xFFE5E5E5),
                        width: 0.5,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _unreadByGroup[course.courseName] = 0;
                          });
                          _saveUnreadCounts();
                          openContainer();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Enhanced avatar with gradient
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      scheme.primary,
                                      scheme.primary.withValues(alpha: 0.8),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: scheme.primary.withValues(
                                        alpha: 0.15,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.transparent,
                                  child: const Icon(
                                    Icons.school,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Course info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      course.courseName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: hasUnread
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1B1B1B),
                                      ),
                                    ),
                                    if (readOnly) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF333333)
                                              : const Color(0xFFF0F0F0),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.lock_outline,
                                              size: 10,
                                              color: isDark
                                                  ? Colors.white70
                                                  : const Color(0xFF666666),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              'Read Only',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: isDark
                                                    ? Colors.white70
                                                    : const Color(0xFF666666),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      lastMessage,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: hasUnread
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xFF666666),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Trailing info
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    lastMessageTime.isNotEmpty
                                        ? _formatTimestamp(lastMessageTime)
                                        : '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white54
                                          : const Color(0xFF8A8A8A),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (hasUnread) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                scheme.primary,
                                                scheme.primary.withValues(
                                                  alpha: 0.8,
                                                ),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: scheme.primary
                                                    .withValues(alpha: 0.15),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
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
                                      ] else if (course.messages.isNotEmpty &&
                                          course
                                              .messages
                                              .last
                                              .isOwnMessage) ...[
                                        Icon(
                                          Icons.done_all,
                                          size: 16,
                                          color: scheme.primary,
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
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
