import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_models.dart';
import '../services/chat_services.dart';
import '../utils/timestamp_utils.dart';
import 'token_input_page.dart';
import '../widgets/network_image.dart';
import '../widgets/app_toast.dart';

// Reuse the same caches from direct_messages_page.dart
final Map<String, Contact> _contactsCacheById = {};
final Map<String, _DmMeta> _dmMetaCacheByGroup = {};
final Map<String, String> _avatarCacheByUserId = {};
bool _contactsLoaded = false;
bool _avatarsLoaded = false;
const String _kAvatarCacheKey = 'dm_avatar_cache_v1';

String _normalizeAvatar(String? url) => (url ?? '').trim();

class DmRequestsPage extends StatefulWidget {
  final WebSocketChatService wsService;

  const DmRequestsPage({
    super.key,
    required this.wsService,
  });

  @override
  State<DmRequestsPage> createState() => _DmRequestsPageState();
}

class _DmRequestsPageState extends State<DmRequestsPage> {
  late List<DirectMessage> _requestMessages;
  StreamSubscription<ChatMessage>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _systemMessageSubscription;
  final ChatApiService _apiService = ChatApiService();

  // Track in-flight loads to avoid duplicate fetches
  final Set<String> _dmMetaLoading = {};

  @override
  void initState() {
    super.initState();
    _initializeRequestMessages();
    _setupWebSocketSubscriptions();
    _loadContactsIfNeeded();
    _loadAvatarCacheIfNeeded();
  }

  void _safeRebuild() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadAvatarCacheIfNeeded() async {
    if (_avatarsLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kAvatarCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> m = jsonDecode(raw);
        _avatarCacheByUserId.clear();
        for (final e in m.entries) {
          final k = e.key;
          final v = e.value?.toString();
          if (v != null && v.isNotEmpty) {
            _avatarCacheByUserId[k] = v;
          }
        }
      }
    } catch (_) {
      // ignore
    } finally {
      _avatarsLoaded = true;
      if (mounted) setState(() {});
    }
  }

  Future<void> _saveAvatarForUser(String userId, String? url) async {
    if (userId.isEmpty || url == null || url.isEmpty) return;
    final existing = _avatarCacheByUserId[userId];
    if (existing == url) return;
    _avatarCacheByUserId[userId] = url;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAvatarCacheKey, jsonEncode(_avatarCacheByUserId));
    } catch (_) {
      // ignore
    }
  }

  void _handleSystemMessage(Map<String, dynamic> message) {
    if (message['type'] == 'force_disconnect') {
      debugPrint('🚪 [DmRequestsPage] Force disconnect received');
      _handleForceDisconnect(message);
    }
  }

  void _handleForceDisconnect(Map<String, dynamic> message) async {
    debugPrint('🚪 [DmRequestsPage] Handling force disconnect');

    // Disconnect WebSocket
    widget.wsService.disconnect();

    // Clear token
    await TokenStorage.clearToken();

    // Show notification
    if (mounted) {
      showAppToast(
        context,
        message['message'] ?? 'You have been disconnected from another device.',
        type: ToastType.error,
        duration: const Duration(seconds: 5),
      );

      // Navigate to login after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const TokenInputApp(autoLoggedOut: true),
            ),
            (route) => false,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _systemMessageSubscription?.cancel();
    super.dispose();
  }

  void _initializeRequestMessages() {
    if (currentUser != null) {
      _requestMessages = [];
      final seenNames = <String>{};

      for (final group in currentUser!.groups) {
        final dmMatch = RegExp(r'^\d+\s*:\s*\d+$').firstMatch(group.name);
        if (dmMatch != null && 
            !seenNames.contains(group.name) && 
            (group.inviteStatus.trim().toUpperCase() == 'REQD' || 
             group.inviteStatus.trim().toUpperCase() == 'BLOCK')) {
          final dm = DirectMessage(
            dmName: group.name,
            participants: group.name,
            lastMessage: group.groupLastMessage,
            lastMessageTime: group.lastMessageTime,
            isActive: group.isActive,
            isAdmin: group.isAdmin,
          );
          _requestMessages.add(dm);
          seenNames.add(group.name);
        }
      }

      _sortRequestMessages();
    } else {
      _requestMessages = [];
    }
  }

  Future<void> _loadContactsIfNeeded() async {
    if (currentUser == null) return;
    if (_contactsLoaded) return;
    try {
      final contacts = await _apiService.fetchContacts(currentUser!.chatToken);
      setState(() {
        for (final c in contacts) {
          _contactsCacheById[c.userid] = c;
        }
        _contactsLoaded = true;
      });
    } catch (e) {
      // Non-fatal. We'll fall back to messages endpoint per DM as needed.
    }
  }

  // Derive the other participant's ID from the DM name (format: "<idA> : <idB>")
  String _otherUserIdForDm(String dmName) {
    final parts = dmName.split(RegExp(r'\s*:\s*'));
    if (parts.length != 2) return dmName;
    final idA = parts[0];
    final idB = parts[1];
    final me = currentUser?.id;
    if (me == idA) return idB;
    if (me == idB) return idA;
    return idB;
  }

  // Lazy-load meta (name/avatar) via messages endpoint, but only if contacts didn't have it
  Future<void> _ensureDmMetaLoaded(String groupId) async {
    if (currentUser == null) return;
    if (_dmMetaCacheByGroup.containsKey(groupId) ||
        _dmMetaLoading.contains(groupId)) {
      return;
    }

    final otherId = _otherUserIdForDm(groupId);
    final contact = _contactsCacheById[otherId];
    final cachedAvatar = _avatarCacheByUserId[otherId];
    if (contact != null || (cachedAvatar != null && cachedAvatar.isNotEmpty)) {
      // Contacts may have name; avatar may be from persistent cache
      final name = (contact != null && contact.name.isNotEmpty)
          ? contact.name
          : otherId;
      final avatarUrl =
          (contact?.userimageurl ?? contact?.avatar) ?? cachedAvatar;
      _dmMetaCacheByGroup[groupId] = _DmMeta(name: name, avatarUrl: avatarUrl);
      _safeRebuild();
      return;
    }

    _dmMetaLoading.add(groupId);
    try {
      final msgs = await _apiService.fetchChatMessages(
        groupId,
        currentUser!.chatToken,
      );
      String name = otherId;
      String? avatar;
      if (msgs.isNotEmpty) {
        // Try to find a message from the other participant
        final other = msgs.firstWhere(
          (m) => !m.isOwnMessage,
          orElse: () => msgs.last,
        );
        if (!other.isOwnMessage) {
          if (other.senderName.isNotEmpty) name = other.senderName;
          avatar = other.userImage;
        }
      }
      _dmMetaCacheByGroup[groupId] = _DmMeta(name: name, avatarUrl: avatar);
      // Persist avatar by userId for future sessions
      await _saveAvatarForUser(otherId, avatar);
      _safeRebuild();
    } catch (_) {
      // Ignore; fallback to ID
    } finally {
      _dmMetaLoading.remove(groupId);
    }
  }

  String _displayNameForDm(DirectMessage dm) {
    final meta = _dmMetaCacheByGroup[dm.dmName];
    if (meta != null && meta.name.isNotEmpty) return meta.name;
    final otherId = _otherUserIdForDm(dm.dmName);
    final contact = _contactsCacheById[otherId];
    if (contact != null && contact.name.isNotEmpty) return contact.name;
    return otherId;
  }

  String? _avatarUrlForDm(DirectMessage dm) {
    final meta = _dmMetaCacheByGroup[dm.dmName];
    if (meta != null && meta.avatarUrl != null && meta.avatarUrl!.isNotEmpty) {
      return _normalizeAvatar(meta.avatarUrl);
    }
    final otherId = _otherUserIdForDm(dm.dmName);
    final contact = _contactsCacheById[otherId];
    final fromContacts = contact?.userimageurl ?? contact?.avatar;
    if (fromContacts != null && fromContacts.isNotEmpty) {
      return _normalizeAvatar(fromContacts);
    }
    return _normalizeAvatar(_avatarCacheByUserId[otherId]);
  }

  void _sortRequestMessages() {
    _requestMessages.sort((a, b) {
      // Parse timestamps, handling empty strings and invalid formats
      DateTime? timeA = _parseTimestamp(a.lastMessageTime);
      DateTime? timeB = _parseTimestamp(b.lastMessageTime);

      // Primary sort: by timestamp (most recent first)
      if (timeA != null && timeB != null) {
        return timeB.compareTo(timeA);
      } else if (timeA != null && timeB == null) {
        return -1;
      } else if (timeA == null && timeB != null) {
        return 1;
      } else {
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

    _systemMessageSubscription = widget.wsService.systemMessageStream.listen((
      message,
    ) {
      _handleSystemMessage(message);
    });
  }

  void _handleNewMessage(ChatMessage message) {
    String groupName = (message.group ?? '').trim();
    int dmIndex = -1;
    if (groupName.isNotEmpty) {
      dmIndex = _requestMessages.indexWhere((dm) => dm.dmName == groupName);
    } else {
      // Fallback: locate DM where participants contain the sender id
      dmIndex = _requestMessages.indexWhere((dm) {
        final parts = dm.dmName.split(RegExp(r'\s*:\s*'));
        return parts.contains(message.sender);
      });
      if (dmIndex != -1) groupName = _requestMessages[dmIndex].dmName;
    }
    if (dmIndex == -1) return;

    setState(() {
      if (currentUser != null) {
        for (int i = 0; i < currentUser!.groups.length; i++) {
          if (currentUser!.groups[i].name == groupName) {
            currentUser!.groups[i] = currentUser!.groups[i].copyWith(
              groupLastMessage: message.message,
              lastMessageTime: message.timestamp,
            );
          }
        }
      }

      _requestMessages[dmIndex] = _requestMessages[dmIndex].copyWith(
        lastMessage: message.message,
        lastMessageTime: message.timestamp,
      );

      _sortRequestMessages();
      TokenStorage.saveCurrentUser();
    });
  }

  Future<void> _acceptRequest(DirectMessage dm) async {
    if (currentUser == null) return;
    
    try {
      // Call API to accept the request
      final result = await _apiService.performGroupAction(
        currentUser!.chatToken,
        'Accept',
        dm.dmName,
      );
      
      if (result.isSuccess) {
        // Remove from requests list
        setState(() {
          _requestMessages.removeWhere((d) => d.dmName == dm.dmName);
        });
        
        // Update the group status in currentUser
        for (int i = 0; i < currentUser!.groups.length; i++) {
          if (currentUser!.groups[i].name == dm.dmName) {
            currentUser!.groups[i] = currentUser!.groups[i].copyWith(
              inviteStatus: 'ACPTD',
            );
          }
        }
        await TokenStorage.saveCurrentUser();
        
        // Show success message
        if (mounted) {
          showAppToast(
            context,
            result.message.isNotEmpty ? result.message : 'You can now chat with ${_displayNameForDm(dm)}',
            type: ToastType.success,
          );
        }
      } else {
        showAppToast(
          context,
          'Failed to accept request: ${result.message}',
          type: ToastType.error,
        );
      }
    } catch (e) {
      showAppToast(
        context,
        'Failed to accept request: $e',
        type: ToastType.error,
      );
    }
  }

  Future<void> _rejectRequest(DirectMessage dm) async {
    if (currentUser == null) return;
    
    try {
      // Call API to reject the request
      final result = await _apiService.performGroupAction(
        currentUser!.chatToken,
        'Reject',
        dm.dmName,
      );
      
      if (result.isSuccess) {
        // Remove from requests list
        setState(() {
          _requestMessages.removeWhere((d) => d.dmName == dm.dmName);
        });
        
        // Update the group status in currentUser
        for (int i = 0; i < currentUser!.groups.length; i++) {
          if (currentUser!.groups[i].name == dm.dmName) {
            currentUser!.groups[i] = currentUser!.groups[i].copyWith(
              inviteStatus: 'REJCT',
            );
          }
        }
        await TokenStorage.saveCurrentUser();
        
        // Show success message
        if (mounted) {
          showAppToast(
            context,
            result.message.isNotEmpty ? result.message : 'Request from ${_displayNameForDm(dm)} has been rejected',
            type: ToastType.success,
          );
        }
      } else {
        showAppToast(
          context,
          'Failed to reject request: ${result.message}',
          type: ToastType.error,
        );
      }
    } catch (e) {
      showAppToast(
        context,
        'Failed to reject request: $e',
        type: ToastType.error,
      );
    }
  }

  Future<void> _blockRequest(DirectMessage dm) async {
    if (currentUser == null) return;
    
    try {
      // Call API to block the request
      final result = await _apiService.performGroupAction(
        currentUser!.chatToken,
        'Block',
        dm.dmName,
      );
      
      if (result.isSuccess) {
        // Remove from requests list
        setState(() {
          _requestMessages.removeWhere((d) => d.dmName == dm.dmName);
        });
        
        // Update the group status in currentUser
        for (int i = 0; i < currentUser!.groups.length; i++) {
          if (currentUser!.groups[i].name == dm.dmName) {
            currentUser!.groups[i] = currentUser!.groups[i].copyWith(
              inviteStatus: 'BLOCK',
            );
          }
        }
        await TokenStorage.saveCurrentUser();
        
        // Show success message
        if (mounted) {
          showAppToast(
            context,
            result.message.isNotEmpty ? result.message : '${_displayNameForDm(dm)} has been blocked',
            type: ToastType.success,
          );
        }
      } else {
        showAppToast(
          context,
          'Failed to block user: ${result.message}',
          type: ToastType.error,
        );
      }
    } catch (e) {
      showAppToast(
        context,
        'Failed to block user: $e',
        type: ToastType.error,
      );
    }
  }

  Future<void> _unblockRequest(DirectMessage dm) async {
    if (currentUser == null) return;
    
    try {
      // Call API to unblock the request
      final result = await _apiService.performGroupAction(
        currentUser!.chatToken,
        'Unblock',
        dm.dmName,
      );
      
      if (result.isSuccess) {
        // Remove from requests list
        setState(() {
          _requestMessages.removeWhere((d) => d.dmName == dm.dmName);
        });
        
        // Update the group status in currentUser
        for (int i = 0; i < currentUser!.groups.length; i++) {
          if (currentUser!.groups[i].name == dm.dmName) {
            currentUser!.groups[i] = currentUser!.groups[i].copyWith(
              inviteStatus: 'ACPTD',
            );
          }
        }
        await TokenStorage.saveCurrentUser();
        
        // Show success message
        if (mounted) {
          showAppToast(
            context,
            result.message.isNotEmpty ? result.message : '${_displayNameForDm(dm)} has been unblocked',
            type: ToastType.success,
          );
        }
      } else {
        showAppToast(
          context,
          'Failed to unblock user: ${result.message}',
          type: ToastType.error,
        );
      }
    } catch (e) {
      showAppToast(
        context,
        'Failed to unblock user: $e',
        type: ToastType.error,
      );
    }
  }

  Widget _buildActionButtons(DirectMessage dm, String? status, ColorScheme scheme) {
    
    // If status is BLOCK, show only unblock button
    if (status == 'BLOCK') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _unblockRequest(dm),
          icon: const Icon(Icons.block_flipped, size: 18),
          label: const Text('Unblock'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }
    
    // For REQD status, show accept, reject, and block buttons
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _rejectRequest(dm),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _acceptRequest(dm),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _blockRequest(dm),
            icon: const Icon(Icons.block, size: 18),
            label: const Text('Block'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'DM Requests',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1B1B1B),
          ),
        ),
        actions: [
          if (_requestMessages.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_requestMessages.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
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
        child: _buildRequestsList(scheme, isDark),
      ),
    );
  }

  Widget _buildRequestsList(ColorScheme scheme, bool isDark) {
    if (_requestMessages.isEmpty) {
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
                Icons.person_add_outlined,
                size: 64,
                color: scheme.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Pending Requests',
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF5A5A5A),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'DM requests will appear here',
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
      itemCount: _requestMessages.length,
      itemBuilder: (context, index) {
        final dm = _requestMessages[index];
        // Kick off lazy load of meta for this group (no-op if already cached)
        _ensureDmMetaLoaded(dm.dmName);
        final displayName = _displayNameForDm(dm);
        final avatarUrl = _avatarUrlForDm(dm);

        // Get the current status of this DM
        String? currentStatus;
        try {
          final grp = currentUser?.groups.firstWhere(
            (g) => g.name == dm.dmName,
          );
          currentStatus = grp?.inviteStatus.trim().toUpperCase();
        } catch (_) {}

        return Container(
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar
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
                              color: scheme.primary.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.transparent,
                          child: avatarUrl != null && avatarUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: SafeNetworkImage(
                                    imageUrl: avatarUrl,
                                    width: 48,
                                    height: 48,
                                    highQuality: true,
                                    fit: BoxFit.cover,
                                    errorWidget: Text(
                                      displayName.isNotEmpty
                                          ? displayName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                )
                              : Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // User info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1B1B1B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Wants to start a conversation',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF666666),
                              ),
                            ),
                            if (dm.lastMessage.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                dm.lastMessage,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: isDark
                                      ? Colors.white60
                                      : const Color(0xFF888888),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Action buttons
                  _buildActionButtons(dm, currentStatus, scheme),
                ],
              ),
            ),
          ),
        )
        .animate(delay: (40 * index).ms)
        .fadeIn(duration: 300.ms, curve: Curves.easeOut)
        .moveY(begin: 8, end: 0, duration: 300.ms, curve: Curves.easeOut);
      },
    );
  }
}

class _DmMeta {
  final String name;
  final String? avatarUrl;
  _DmMeta({required this.name, this.avatarUrl});
}
