import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_models.dart';
import '../services/chat_services.dart';
import '../utils/timestamp_utils.dart';
import 'token_input_page.dart';
import 'new_dm_page.dart';
import 'chat_page.dart';
import '../widgets/network_image.dart';

// Persistent caches (per app session)
final Map<String, Contact> _contactsCacheById = {};
final Map<String, _DmMeta> _dmMetaCacheByGroup = {};
final Map<String, String> _avatarCacheByUserId = {};
bool _contactsLoaded = false;
bool _avatarsLoaded = false;
const String _kAvatarCacheKey = 'dm_avatar_cache_v1';

class DirectMessagesPage extends StatefulWidget {
  final WebSocketChatService wsService;

  const DirectMessagesPage({super.key, required this.wsService});

  @override
  State<DirectMessagesPage> createState() => _DirectMessagesPageState();
}

class _DirectMessagesPageState extends State<DirectMessagesPage> {
  final TextEditingController _messageController = TextEditingController();
  late List<DirectMessage> _directMessages;
// kept for state/back compat but not used for inline view
  StreamSubscription<ChatMessage>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _systemMessageSubscription;
  String _query = '';
  final ChatApiService _apiService = ChatApiService();

  // Track in-flight loads to avoid duplicate fetches
  final Set<String> _dmMetaLoading = {};

  @override
  void initState() {
    super.initState();
    _initializeDMs();
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
          content: Text(
            message['message'] ??
                'You have been disconnected from another device.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
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
    if (_dmMetaCacheByGroup.containsKey(groupId) || _dmMetaLoading.contains(groupId)) return;

    final otherId = _otherUserIdForDm(groupId);
    final contact = _contactsCacheById[otherId];
    final cachedAvatar = _avatarCacheByUserId[otherId];
    if (contact != null || (cachedAvatar != null && cachedAvatar.isNotEmpty)) {
      // Contacts may have name; avatar may be from persistent cache
      final name = (contact != null && contact.name.isNotEmpty) ? contact.name : otherId;
      final avatarUrl = (contact?.userimageurl ?? contact?.avatar) ?? cachedAvatar;
      _dmMetaCacheByGroup[groupId] = _DmMeta(name: name, avatarUrl: avatarUrl);
      _safeRebuild();
      return;
    }

    _dmMetaLoading.add(groupId);
    try {
      final msgs = await _apiService.fetchChatMessages(groupId, currentUser!.chatToken);
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
    if (meta != null && meta.avatarUrl != null && meta.avatarUrl!.isNotEmpty) return meta.avatarUrl;
    final otherId = _otherUserIdForDm(dm.dmName);
    final contact = _contactsCacheById[otherId];
    final fromContacts = contact?.userimageurl ?? contact?.avatar;
    if (fromContacts != null && fromContacts.isNotEmpty) return fromContacts;
    return _avatarCacheByUserId[otherId];
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

    _systemMessageSubscription = widget.wsService.systemMessageStream.listen((
      message,
    ) {
      _handleSystemMessage(message);
    });
  }

  void _handleNewMessage(ChatMessage message) {
    final exists = _directMessages.indexWhere(
      (dm) => dm.dmName == message.sender,
    );
    if (exists == -1) return;

    setState(() {
      if (currentUser != null) {
        for (int i = 0; i < currentUser!.groups.length; i++) {
          if (currentUser!.groups[i].name == message.sender) {
            currentUser!.groups[i] = currentUser!.groups[i].copyWith(
              groupLastMessage: message.message,
              lastMessageTime: message.timestamp,
            );
          }
        }
      }

      final dmIndex = _directMessages.indexWhere(
        (dm) => dm.dmName == message.sender,
      );
      if (dmIndex != -1) {
        _directMessages[dmIndex] = _directMessages[dmIndex].copyWith(
          lastMessage: message.message,
          lastMessageTime: message.timestamp,
        );
      }

      _sortDirectMessages();
      TokenStorage.saveCurrentUser();
    });
  }

  Future<void> _selectDM(DirectMessage dm) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatPage(
          groupId: dm.dmName,
          title: _displayNameForDm(dm),
          wsService: widget.wsService,
          isReadOnly: false,
        ),
      ),
    );
  }

  Future<void> _startNewDM() async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (context) => const NewDMPage()));

    // If a new DM was created successfully, refresh the DM list
    if (result == true) {
      _initializeDMs();
    }
  }


  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = _directMessages
        .where((dm) {
          if (_query.isEmpty) return true;
          final name = _displayNameForDm(dm).toLowerCase();
          return name.contains(_query.toLowerCase());
        })
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Direct Messages')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SearchBar(
              leading: const Icon(Icons.search),
              hintText: 'Search people',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildDMList(filtered, scheme)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startNewDM,
        tooltip: 'Start New DM',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDMList(List<DirectMessage> data, ColorScheme scheme) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.message, size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'No Direct Messages',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Direct messages will appear here',
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
        final dm = data[index];
        // Kick off lazy load of meta for this group (no-op if already cached)
        _ensureDmMetaLoaded(dm.dmName);
        final displayName = _displayNameForDm(dm);
        final avatarUrl = _avatarUrlForDm(dm);

        // Derive status from currentUser group metadata
        String? status;
        try {
          final grp = currentUser?.groups.firstWhere((g) => g.name == dm.dmName);
          status = grp?.inviteStatus.isNotEmpty == true ? grp!.inviteStatus : null;
        } catch (_) {}

        return Card(
          key: ValueKey(dm.dmName),
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: avatarUrl != null && avatarUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SafeNetworkImage(
                      imageUrl: avatarUrl,
                      width: 40,
                      height: 40,
                      highQuality: true,
                      fit: BoxFit.cover,
                      errorWidget: CircleAvatar(
                        radius: 20,
                        backgroundColor: scheme.primary,
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                : CircleAvatar(
                    radius: 20,
                    backgroundColor: scheme.primary,
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Text(
                    displayName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (status != null && status.trim().toUpperCase() != 'ACPTD') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
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
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            onTap: () => _selectDM(dm),
          ),
        );
      },
    );
  }

  // Inline chat UI removed; ChatPage handles chat display

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

class _DmMeta {
  final String name;
  final String? avatarUrl;
  _DmMeta({required this.name, this.avatarUrl});
}
