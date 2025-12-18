// Flutter imports:
import 'package:flutter/material.dart';

// Project imports:
import '../models/contact_model.dart';
import '../models/user_models.dart';
import '../services/avatar_cache_service.dart';
import '../services/chat_services.dart';
import '../widgets/app_toast.dart';
import '../widgets/network_image.dart';

class InviteMembersPage extends StatefulWidget {
  final String groupName;
  final String groupId;

  const InviteMembersPage({
    super.key,
    required this.groupName,
    required this.groupId,
  });

  @override
  State<InviteMembersPage> createState() => _InviteMembersPageState();
}

class _InviteMembersPageState extends State<InviteMembersPage> {
  final ChatApiService _apiService = ChatApiService();

  final Set<String> _selectedUserIds = <String>{};
  final List<Contact> _contacts = <Contact>[];

  bool _isLoadingContacts = false;
  bool _isInviting = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    if (currentUser == null) return;

    setState(() {
      _isLoadingContacts = true;
    });

    try {
      debugPrint('🔄 [InviteMembersPage] Fetching contacts for invites...');
      final contacts = await _apiService.fetchContacts(currentUser!.chatToken);

      // Cache userimageurl from contacts for avatar usage elsewhere
      for (final contact in contacts) {
        if (contact.userimageurl != null && contact.userimageurl!.isNotEmpty) {
          await AvatarCacheService.cacheAvatar(
            contact.userid,
            contact.userimageurl,
          );
          debugPrint(
            '💾 [InviteMembersPage] Cached userimageurl for ${contact.userid}: ${contact.userimageurl}',
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _contacts
          ..clear()
          ..addAll(contacts);
        _isLoadingContacts = false;
      });
    } catch (e) {
      debugPrint('❌ [InviteMembersPage] Error fetching contacts: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingContacts = false;
      });
      showAppToast(
        context,
        'Failed to load contacts. Please try again.',
        type: ToastType.error,
      );
    }
  }

  Future<void> _submitInvites() async {
    if (currentUser == null) return;
    if (_selectedUserIds.isEmpty) {
      showAppToast(
        context,
        'Please select at least one member to invite.',
        type: ToastType.warning,
      );
      return;
    }
    if (_isInviting) return;

    setState(() {
      _isInviting = true;
    });

    try {
      final usersCsv = _selectedUserIds.join(',');
      debugPrint('🚀 [InviteMembersPage] Inviting members...');
      debugPrint(
        '📤 [InviteMembersPage] Request Body: {"ChatToken": "${currentUser!.chatToken}", "Action": "Invite", "Group": "${widget.groupId}", "Users": "$usersCsv"}',
      );

      final result = await _apiService.performGroupAction(
        currentUser!.chatToken,
        'Invite',
        widget.groupId,
        users: usersCsv,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        debugPrint(
          '✅ [InviteMembersPage] Members invited successfully: ${result.message}',
        );
        showAppToast(
          context,
          result.message.isNotEmpty
              ? result.message
              : 'Invitations sent successfully.',
          type: ToastType.success,
        );
        Navigator.of(context).pop(true);
      } else {
        debugPrint(
          '❌ [InviteMembersPage] Failed to invite members: ${result.message}',
        );
        showAppToast(
          context,
          result.message.isNotEmpty
              ? result.message
              : 'Failed to invite members.',
          type: ToastType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('❌ [InviteMembersPage] Error sending invites: $e');
      showAppToast(
        context,
        'Error sending invites: $e',
        type: ToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isInviting = false;
        });
      }
    }
  }

  Widget _buildAvatar(Contact contact, ColorScheme scheme) {
    if (contact.userimageurl != null && contact.userimageurl!.isNotEmpty) {
      return ClipOval(
        child: SafeNetworkImage(
          imageUrl: contact.userimageurl!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorWidget: CircleAvatar(
            backgroundColor: scheme.primary,
            child: Text(
              contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      backgroundColor: scheme.primary,
      child: Text(
        contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Members'),
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
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
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
                      Icon(Icons.group_add, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Select members to invite',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.groupName,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoadingContacts
                  ? const Center(child: CircularProgressIndicator())
                  : _contacts.isEmpty
                      ? const Center(
                          child: Text('No contacts available to invite.'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _contacts.length,
                          itemBuilder: (context, index) {
                            final contact = _contacts[index];
                            final isSelected =
                                _selectedUserIds.contains(contact.userid);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: CheckboxListTile(
                                value: isSelected,
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _selectedUserIds.add(contact.userid);
                                    } else {
                                      _selectedUserIds.remove(contact.userid);
                                    }
                                  });
                                },
                                secondary: _buildAvatar(contact, scheme),
                                title: Text(
                                  contact.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  contact.category,
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isInviting ? null : _submitInvites,
                    icon: _isInviting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      _isInviting ? 'Sending invitations...' : 'Send invites',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
