// Flutter imports:
import 'package:flutter/material.dart';

// Project imports:
import '../models/user_models.dart';
import '../services/avatar_cache_service.dart';
import '../services/chat_services.dart';
import '../widgets/app_toast.dart';
import '../widgets/network_image.dart';

class NewGroupPage extends StatefulWidget {
  const NewGroupPage({super.key});

  @override
  State<NewGroupPage> createState() => _NewGroupPageState();
}

class _NewGroupPageState extends State<NewGroupPage> {
  final ChatApiService _apiService = ChatApiService();
  final TextEditingController _groupNameController = TextEditingController();

  List<Contact> _contacts = [];
  final Set<String> _selectedMemberIds = {};
  bool _isLoadingContacts = true;
  bool _isCreatingGroup = false;
  bool _isTwoWay = true; // true => everyone can message; false => only admin

  @override
  void initState() {
    super.initState();
    _loadAvatarCache();
    _loadContacts();
  }

  Future<void> _loadAvatarCache() async {
    await AvatarCacheService.loadCache();
  }

  String? _getAvatarUrlForContact(Contact contact) {
    // First try contact's own avatar fields
    final contactAvatar = contact.userimageurl ?? contact.avatar;
    if (contactAvatar != null && contactAvatar.isNotEmpty) {
      return contactAvatar;
    }

    // Then try cached avatar
    return AvatarCacheService.getCachedAvatar(contact.userid);
  }

  Widget _buildContactAvatar(
    Contact contact,
    ColorScheme scheme, {
    double size = 32,
  }) {
    final avatarUrl = _getAvatarUrlForContact(contact);

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: scheme.primary,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: SafeNetworkImage(
            imageUrl: avatarUrl,
            width: size,
            height: size,
            errorWidget: CircleAvatar(
              radius: size / 2,
              backgroundColor: scheme.primary,
              child: Text(
                contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.4,
                ),
              ),
            ),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Fallback to initials
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: scheme.primary,
      child: Text(
        contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    if (currentUser == null) return;

    setState(() {
      _isLoadingContacts = true;
    });

    try {
      debugPrint('🔄 [NewGroupPage] Fetching contacts for group creation...');
      final contacts = await _apiService.fetchContacts(currentUser!.chatToken);

      // Cache userimageurl from contacts
      for (final contact in contacts) {
        if (contact.userimageurl != null && contact.userimageurl!.isNotEmpty) {
          await AvatarCacheService.cacheAvatar(
            contact.userid,
            contact.userimageurl,
          );
          debugPrint(
            '💾 [NewGroupPage] Cached userimageurl for ${contact.userid}: ${contact.userimageurl}',
          );
        }
      }

      setState(() {
        _contacts = contacts;
        _isLoadingContacts = false;
      });
    } catch (e) {
      debugPrint('❌ [NewGroupPage] Error fetching contacts: $e');
      setState(() {
        _isLoadingContacts = false;
      });
      if (mounted) {
        showAppToast(
          context,
          'Failed to load contacts. Please try again.',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _createGroup() async {
    if (currentUser == null) return;

    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      showAppToast(
        context,
        'Please enter a group name.',
        type: ToastType.warning,
      );
      return;
    }

    if (_selectedMemberIds.length < 2) {
      // Require at least 2 selected contacts (members) to create a group
      showAppToast(
        context,
        'Please select at least 2 members for the group.',
        type: ToastType.warning,
      );
      return;
    }

    if (_isCreatingGroup) return;

    setState(() {
      _isCreatingGroup = true;
    });

    try {
      final members = _selectedMemberIds.join(',');
      debugPrint('🚀 [NewGroupPage] Creating private group...');
      debugPrint(
        '📤 [NewGroupPage] Request Body: {"ChatToken": "${currentUser!.chatToken}", "GroupName": "$groupName", "is_two_way": $_isTwoWay, "Members": "$members", "one_To_One": false}',
      );

      final result = await _apiService.createGroup(
        currentUser!.chatToken,
        groupName,
        members,
        isTwoWay: _isTwoWay,
        oneToOne: false,
      );

      debugPrint('📥 [NewGroupPage] Create Group Response: ${result.toString()}');

      if (result.isSuccess) {
        debugPrint('✅ [NewGroupPage] Group created successfully: ${result.name}');
        if (!mounted) return;
        showAppToast(
          context,
          'Group created successfully!',
          type: ToastType.success,
        );
        Navigator.of(context).pop(true); // indicate success
      } else {
        debugPrint('❌ [NewGroupPage] Failed to create group: ${result.message}');
        if (!mounted) return;
        showAppToast(
          context,
          'Failed to create group: ${result.message}',
          type: ToastType.error,
        );
      }
    } catch (e) {
      debugPrint('❌ [NewGroupPage] Error creating group: $e');
      if (!mounted) return;

      // Handle specific case where group already exists
      if (e.toString().contains('Group Already exists') ||
          e.toString().contains('400')) {
        showAppToast(
          context,
          'Group already exists with this name!',
          type: ToastType.warning,
        );
        Navigator.of(context).pop(true);
      } else {
        showAppToast(
          context,
          'Error creating group: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingGroup = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Create Private Group',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1B1B1B),
          ),
        ),
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
            // Group details section
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.group_add, color: scheme.primary, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Group Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _groupNameController,
                    decoration: InputDecoration(
                      labelText: 'Group Name',
                      hintText: 'Enter a name for your group',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: scheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: scheme.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor:
                          scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Messaging Permissions',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isTwoWay
                                  ? 'Everyone in the group can send messages.'
                                  : 'Only you (admin) can send messages.',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isTwoWay,
                        onChanged: (value) {
                          setState(() {
                            _isTwoWay = value;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Members list
            Expanded(
              child: _isLoadingContacts
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: scheme.primary),
                          const SizedBox(height: 16),
                          Text(
                            'Loading your contacts...',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _contacts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: scheme.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No contacts available',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'You need at least 2 members to create a group.',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.people,
                                    color: scheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Select Members',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: scheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${_selectedMemberIds.length} selected',
                                      style: TextStyle(
                                        color: scheme.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _contacts.length,
                                itemBuilder: (context, index) {
                                  final contact = _contacts[index];
                                  final isSelected =
                                      _selectedMemberIds.contains(contact.userid);

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    color: isSelected
                                        ? scheme.primaryContainer
                                        : null,
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      leading: _buildContactAvatar(
                                        contact,
                                        scheme,
                                      ),
                                      title: Text(
                                        contact.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: scheme.onSurface,
                                        ),
                                      ),
                                      subtitle: Text(
                                        contact.category,
                                        style: TextStyle(
                                          color: scheme.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: Checkbox(
                                        value: isSelected,
                                        onChanged: (value) {
                                          setState(() {
                                            if (value == true) {
                                              _selectedMemberIds
                                                  .add(contact.userid);
                                            } else {
                                              _selectedMemberIds
                                                  .remove(contact.userid);
                                            }
                                          });
                                        },
                                      ),
                                      onTap: () {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedMemberIds
                                                .remove(contact.userid);
                                          } else {
                                            _selectedMemberIds
                                                .add(contact.userid);
                                          }
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isCreatingGroup ? null : _createGroup,
              icon: _isCreatingGroup
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _isCreatingGroup ? 'Creating Group...' : 'Create Group',
              ),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
