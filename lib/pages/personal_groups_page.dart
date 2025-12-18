// Dart imports:
import 'dart:async';
import 'dart:convert';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:animations/animations.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import '../models/current_user_state.dart';
import '../models/user_models.dart';
import '../services/chat_services.dart';
import '../services/haptic_feedback_service.dart';
import '../services/read_tracker.dart';
import '../utils/animations.dart';
import '../utils/group_utils.dart';
import '../utils/layout_utils.dart';
import '../utils/timestamp_utils.dart';
import '../widgets/app_toast.dart';
import '../widgets/empty_states.dart';
import '../widgets/skeleton_loaders.dart';
import 'chat_page.dart';
import 'login_page.dart';
import 'new_group_page.dart';

// Drawer is provided by parent Scaffold; do not declare here

class PersonalGroupsPage extends StatefulWidget {
  final WebSocketChatService wsService;
  final VoidCallback? onOpenDrawer;

  const PersonalGroupsPage({
    super.key,
    required this.wsService,
    this.onOpenDrawer,
  });

  @override
  State<PersonalGroupsPage> createState() => _PersonalGroupsPageState();
}

class _PersonalGroupsPageState extends State<PersonalGroupsPage> {
  late List<Group> _personalGroups;
  StreamSubscription<ChatMessage>? _messageSubscription;
  String _query = '';
  late final VoidCallback _userListener;
  bool _isInitialLoading = true;

  // Unread counters per personal group
  final Map<String, int> _unreadByGroup = {};
  final ChatApiService _apiService = ChatApiService();
  static const String _kUnreadPersonalKey = 'unread_personal_counts_v1';

  Future<void> _loadUnreadCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kUnreadPersonalKey);
      if (raw == null || raw.isEmpty) return;
      final Map<String, dynamic> m = jsonDecode(raw);
      _unreadByGroup.clear();
      final existing = _personalGroups.map((g) => g.name).toSet();
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
      await prefs.setString(_kUnreadPersonalKey, jsonEncode(_unreadByGroup));
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _initializeGroups();
    _setupWebSocketSubscription();
    _loadUnreadCounts().then((_) {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
    });

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
    _messageSubscription?.cancel();
    currentUserNotifier.removeListener(_userListener);
    super.dispose();
  }

  void _initializeGroups() {
    if (currentUser != null) {
      _personalGroups = [];
      final seenNames = <String>{};

      for (final group in currentUser!.groups) {
        // Use utility function to check if this is a personal group
        if (isPersonalGroup(group.name, group) && !seenNames.contains(group.name)) {
          _personalGroups.add(group);
          _unreadByGroup.putIfAbsent(group.name, () => 0);
          seenNames.add(group.name);
        }
      }

      _sortPersonalGroups();
    } else {
      _personalGroups = [];
    }
  }

  void _sortPersonalGroups() {
    _personalGroups.sort((a, b) {
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
      return a.name.compareTo(b.name);
    });
  }

  DateTime? _parseTimestamp(String timestamp) {
    return TimestampUtils.parseTimestamp(timestamp);
  }

  int _indexForIncomingMessage(ChatMessage message) {
    final incomingGroup = (message.group ?? '').trim();
    if (incomingGroup.isEmpty) return -1;
    return _personalGroups.indexWhere(
      (g) => g.name == incomingGroup || g.name.toLowerCase() == incomingGroup.toLowerCase(),
    );
  }

  void _setupWebSocketSubscription() {
    _messageSubscription = widget.wsService.messageStream.listen((message) {
      final index = _indexForIncomingMessage(message);
      if (index != -1) {
        final group = _personalGroups[index];
        final groupKey = group.name;

        // Update the group with new message info
        _personalGroups[index] = group.copyWith(
          groupLastMessage: message.message,
          lastMessageTime: message.timestamp,
        );

        if (!message.isOwnMessage && !OpenConversations.isOpen(groupKey)) {
          _unreadByGroup.update(groupKey, (v) => v + 1, ifAbsent: () => 1);
          _saveUnreadCounts();
        }
        _sortPersonalGroups();
        setState(() {});
      }
    });
  }

  bool _isGroupWritable(Group group) {
    return group.isActive && (group.isTwoWay || group.isAdmin);
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
    final filtered = _personalGroups
        .where(
          (g) =>
              _query.isEmpty ||
              g.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            HapticFeedbackService.buttonPress();
            debugPrint('🫓 PersonalGroupsPage hamburger tapped');
            widget.onOpenDrawer?.call();
          },
          tooltip: 'Menu',
        ),
        title: Text(
          'Personal Groups',
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
                hintText: 'Search groups',
                onChanged: (v) {
                  if (v.isNotEmpty && _query.isEmpty) {
                    HapticFeedbackService.selection();
                  }
                  setState(() => _query = v);
                },
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
                onRefresh: _refreshGroups,
                color: scheme.primary,
                child: _buildGroupList(filtered, scheme, isDark),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 88),
        child: SizedBox(
          width: 56,
          height: 56,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: DecoratedBox(
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
                    color: scheme.primary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  splashColor: Colors.white.withValues(alpha: 0.12),
                  highlightColor: Colors.white.withValues(alpha: 0.06),
                  customBorder: const CircleBorder(),
                  onTap: () async {
                    HapticFeedbackService.buttonPress();
                    final created = await Navigator.of(context).push(
                      SlidePageRoute(
                        page: const NewGroupPage(),
                        direction: SlideDirection.right,
                      ),
                    );
                    if (created == true && currentUser != null) {
                      // User data (groups) is refreshed inside ChatApiService.createGroup via authorizeUser.
                      _initializeGroups();
                      setState(() {});
                      if (mounted) {
                        showAppToast(
                          context,
                          'Personal group created successfully',
                          type: ToastType.success,
                        );
                      }
                    }
                  },
                  child: const Center(
                    child: Icon(Icons.add_rounded, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshGroups() async {
    if (currentUser == null) return;
    try {
      // First, refresh user data with authorize endpoint
      try {
        debugPrint(
          '🔄 [PersonalGroupsPage] Refreshing user data via authorize endpoint...',
        );
        final updatedUser = await _apiService.authorizeUser(
          currentUser!.chatToken,
        );
        setCurrentUser(updatedUser);
        await TokenStorage.saveCurrentUser();
        debugPrint('✅ [PersonalGroupsPage] User data refreshed successfully');
      } catch (e) {
        if (e is UnauthorizedException) {
          debugPrint(
            '❌ [PersonalGroupsPage] User unauthorized, logging out...',
          );
          await TokenStorage.clearToken();
          setCurrentUser(null);
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const LoginScreen(autoLoggedOut: true),
              ),
            );
          }
          return;
        } else if (e is NetworkException) {
          debugPrint(
            '🌐 [PersonalGroupsPage] Network error during refresh: $e',
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
        debugPrint('⚠️ [PersonalGroupsPage] Failed to refresh user data: $e');
        // Continue with refresh even if authorize fails for other errors
      }

      // The authorize endpoint already updated currentUser.groups with
      // groupLastMessage and lastMessageTime for all groups.
      // Just reinitialize the groups list from the updated currentUser data.
      _initializeGroups();
      if (mounted) setState(() {});
      await _saveUnreadCounts();
    } finally {}
  }

  Widget _buildGroupList(List<Group> data, ColorScheme scheme, bool isDark) {
    // Show skeleton loader during initial load
    if (_isInitialLoading) {
      return SkeletonList(
        itemCount: 6,
        showAvatar: true,
        showSubtitle: true,
      );
    }

    // Show empty state if no groups
    if (data.isEmpty) {
      if (_query.isNotEmpty) {
        return const EmptySearchState(query: '');
      }
      return const EmptyGroupsState(
        title: 'No Personal Groups',
        subtitle: 'Tap the + button to create a new personal group',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + LayoutUtils.getBottomNavBarPadding(context),
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final group = data[index];
        final lastMessage = group.groupLastMessage.isNotEmpty
            ? group.groupLastMessage
            : 'No messages yet';
        final lastMessageTime = group.lastMessageTime.isNotEmpty
            ? group.lastMessageTime
            : '';
        final readOnly = !_isGroupWritable(group);
        final unread = _unreadByGroup[group.name] ?? 0;
        final hasUnread = unread > 0;

        return OpenContainer(
              transitionType: ContainerTransitionType.fadeThrough,
              closedElevation: 0,
              openElevation: 0,
              closedColor: Colors.transparent,
              closedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              openColor: Theme.of(context).colorScheme.surface,
              openBuilder: (context, _) {
                // Clear unread counter when opening (UI badge)
                _unreadByGroup[group.name] = 0;
                _saveUnreadCounts();
                // Clear notifications for this group
                WebSocketChatService.clearGroupNotifications(group.name);
                final isWritable = _isGroupWritable(group);
                return ChatPage(
                  groupId: group.name,
                  title: group.name,
                  wsService: widget.wsService,
                  isReadOnly: !isWritable,
                );
              },
              transitionDuration: const Duration(milliseconds: 300),
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
                          HapticFeedbackService.buttonPress();
                          setState(() {
                            _unreadByGroup[group.name] = 0;
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
                                    Icons.group,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Group info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      group.name,
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
                                  if (hasUnread)
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
            .animate(delay: (30 * index).ms)
            .fadeIn(duration: 250.ms, curve: Curves.easeOut)
            .moveY(begin: 10, end: 0, duration: 300.ms, curve: Curves.easeOutCubic);
      },
    );
  }
}
