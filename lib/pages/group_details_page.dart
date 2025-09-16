import 'package:flutter/material.dart';
import '../models/group_user_model.dart';
import '../models/user_models.dart';
import '../services/chat_services.dart';
import '../services/avatar_cache_service.dart';
import '../widgets/network_image.dart';
import '../widgets/app_toast.dart';

class GroupDetailsPage extends StatefulWidget {
  final String groupName;
  final String groupId;

  const GroupDetailsPage({
    super.key,
    required this.groupName,
    required this.groupId,
  });

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  final ChatApiService _apiService = ChatApiService();
  GroupDetails? _groupDetails;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAvatarCache();
    _loadGroupDetails();
  }

  Future<void> _loadAvatarCache() async {
    await AvatarCacheService.loadCache();
    
    // Debug: Print all cached avatars
    final allCachedAvatars = AvatarCacheService.getAllCachedAvatars();
    print('🔍 [GroupDetailsPage] All cached avatars: $allCachedAvatars');
    print('🔍 [GroupDetailsPage] Cache size: ${AvatarCacheService.getCacheSize()}');
  }

  Widget _buildUserAvatar(GroupUser user, ColorScheme scheme) {
    // Try to get cached avatar for this user
    // Try multiple ID formats since the cache might use different formats
    String? cachedAvatar = AvatarCacheService.getCachedAvatar(user.id);
    
    // If not found, try with current user ID prefix (for DM format)
    if (cachedAvatar == null && currentUser != null) {
      final dmFormatId = '${currentUser!.id} : ${user.id}';
      cachedAvatar = AvatarCacheService.getCachedAvatar(dmFormatId);
    }
    
    // If still not found, try reverse format
    if (cachedAvatar == null && currentUser != null) {
      final reverseDmFormatId = '${user.id} : ${currentUser!.id}';
      cachedAvatar = AvatarCacheService.getCachedAvatar(reverseDmFormatId);
    }
    
    // Debug: Print what we're looking for
    print('🔍 [GroupDetailsPage] Looking for avatar for user: ${user.id}');
    print('🔍 [GroupDetailsPage] Found cached avatar: ${cachedAvatar != null ? "YES" : "NO"}');
    if (cachedAvatar != null) {
      print('🔍 [GroupDetailsPage] Cached avatar URL: $cachedAvatar');
    }
    
    if (cachedAvatar != null && cachedAvatar.isNotEmpty) {
      return CircleAvatar(
        backgroundColor: scheme.primary,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SafeNetworkImage(
            imageUrl: cachedAvatar,
            width: 32,
            height: 32,
            errorWidget: CircleAvatar(
              backgroundColor: scheme.primary,
              child: Text(
                user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
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
      backgroundColor: scheme.primary,
      child: Text(
        user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _loadGroupDetails() async {
    if (currentUser == null) {
      setState(() {
        _error = 'User not authenticated';
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Debug: Print the group name being used
      print('🔍 [GroupDetailsPage] Using group name: "${widget.groupName}"');
      print('🔍 [GroupDetailsPage] Group ID: "${widget.groupId}"');

      GroupDetails groupDetails;
      try {
        groupDetails = await _apiService.fetchGroupUsers(
          currentUser!.chatToken,
          widget.groupName,
        );
      } catch (e) {
        // If the API call fails, try to find the correct group name from user's groups
        if (e.toString().contains('404') || e.toString().contains('not found')) {
          print('🔍 [GroupDetailsPage] Group not found, searching in user groups...');
          
          // Try to find a matching group in the user's groups
          String? correctGroupName;
          for (final group in currentUser!.groups) {
            if (group.name.contains(widget.groupId) || widget.groupId.contains(group.name)) {
              correctGroupName = group.name;
              print('🔍 [GroupDetailsPage] Found matching group: "$correctGroupName"');
              break;
            }
          }
          
          if (correctGroupName != null) {
            groupDetails = await _apiService.fetchGroupUsers(
              currentUser!.chatToken,
              correctGroupName,
            );
          } else {
            rethrow; // Re-throw the original error if no match found
          }
        } else {
          rethrow; // Re-throw non-404 errors
        }
      }

      setState(() {
        _groupDetails = groupDetails;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      
      if (mounted) {
        showAppToast(
          context,
          'Failed to load group details: $e',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        actions: [
          IconButton(
            onPressed: _loadGroupDetails,
            icon: const Icon(Icons.refresh),
          ),
          if (_isCurrentUserAdminOfGroup())
            IconButton(
              tooltip: 'Delete Group',
              icon: const Icon(Icons.delete_forever_outlined),
              color: scheme.error,
              onPressed: _confirmAndDeleteGroup,
            ),
          if (!_isCurrentUserAdminOfGroup() && !_isUniversityGroup())
            IconButton(
              tooltip: 'Leave Group',
              icon: const Icon(Icons.exit_to_app),
              onPressed: _confirmAndLeaveGroup,
            ),
        ],
      ),
      body: _buildBody(scheme),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading group details...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: scheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading group details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: scheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGroupDetails,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_groupDetails == null) {
      return const Center(
        child: Text('No group details available'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGroupInfoCard(scheme),
          const SizedBox(height: 24),
          _buildMembersSection(scheme),
        ],
      ),
    );
  }

  Widget _buildGroupInfoCard(ColorScheme scheme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.group,
                  color: scheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Group Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              'Group Name',
              widget.groupName,
              Icons.label_outline,
              scheme,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Group ID',
              widget.groupId,
              Icons.fingerprint,
              scheme,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Type',
              _groupDetails!.isOneToOne ? 'One-to-One Chat' : 'Group Chat',
              Icons.chat_bubble_outline,
              scheme,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Two-Way Status',
              _groupDetails!.twoWayStatus ? 'Enabled' : 'Disabled',
              Icons.swap_horiz,
              scheme,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Total Members',
              '${_groupDetails!.users.length}',
              Icons.people_outline,
              scheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, ColorScheme scheme) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: scheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: scheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  bool _isCurrentUserAdminOfGroup() {
    if (currentUser == null) return false;
    try {
      final g = currentUser!.groups.firstWhere((x) => x.name == widget.groupName);
      return g.isAdmin == true;
    } catch (_) {
      return false;
    }
  }

  bool _isUniversityGroup() {
    // Prefer flags from current user groups when available
    try {
      final g = currentUser?.groups.firstWhere((x) => x.name == widget.groupName);
      if (g != null) return g.isUniversityGroup;
    } catch (_) {}
    // If group not found, default to uni (safer default for destructive UI)
    return true;
  }

  Future<void> _confirmAndDeleteGroup() async {
    if (currentUser == null) return;
    final scheme = Theme.of(context).colorScheme;

    final controller = TextEditingController();
    final requiredText = 'delete ${widget.groupId}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm Delete Group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This action cannot be undone. To confirm, type the following exactly:',
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(requiredText, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Type confirmation',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () {
                if (controller.text.trim() == requiredText) {
                  Navigator.of(ctx).pop(true);
                }
              },
              style: ButtonStyle(
                foregroundColor: WidgetStatePropertyAll<Color>(scheme.onErrorContainer),
                backgroundColor: WidgetStatePropertyAll<Color>(scheme.errorContainer),
              ),
              child: const Text('Delete Group'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      showAppToast(context, 'Deletion cancelled', type: ToastType.info);
      return;
    }

    try {
      final res = await _apiService.performCriticalGroupAction(
        currentUser!.chatToken,
        'deletegroup',
        widget.groupId,
      );

      if (res.isSuccess) {
        if (mounted) {
          showAppToast(context, 'Group deleted', type: ToastType.success);
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) {
          showAppToast(context, 'Failed: ${res.message}', type: ToastType.error);
        }
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Error: $e', type: ToastType.error);
      }
    }
  }

  Future<void> _confirmAndLeaveGroup() async {
    if (currentUser == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Leave Group?'),
          content: const Text(
            'You will stop receiving messages from this group. Proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final res = await _apiService.performGroupAction(
        currentUser!.chatToken,
        'Leave',
        widget.groupId,
      );

      if (res.isSuccess) {
        if (mounted) {
          showAppToast(context, 'Left group', type: ToastType.success);
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) {
          showAppToast(context, 'Failed: ${res.message}', type: ToastType.error);
        }
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Error: $e', type: ToastType.error);
      }
    }
  }

  Widget _buildMembersSection(ColorScheme scheme) {
    // Sort users: staff first, then others, all sorted alphabetically by name
    final sortedUsers = List<GroupUser>.from(_groupDetails!.users);
    sortedUsers.sort((a, b) {
      // First, sort by category (staff first)
      if (a.category.toLowerCase() == 'staff' && b.category.toLowerCase() != 'staff') {
        return -1;
      } else if (a.category.toLowerCase() != 'staff' && b.category.toLowerCase() == 'staff') {
        return 1;
      }
      // Then sort alphabetically by username
      return a.username.toLowerCase().compareTo(b.username.toLowerCase());
    });

    // Separate staff and non-staff users
    final staffUsers = sortedUsers.where((user) => user.category.toLowerCase() == 'staff').toList();
    final otherUsers = sortedUsers.where((user) => user.category.toLowerCase() != 'staff').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.people,
              color: scheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Members (${_groupDetails!.users.length})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Staff section
        if (staffUsers.isNotEmpty) ...[
          _buildCategoryHeader('Staff', staffUsers.length, scheme),
          const SizedBox(height: 8),
          ...staffUsers.map((user) => _buildMemberCard(user, scheme)),
          if (otherUsers.isNotEmpty) const SizedBox(height: 16),
        ],
        
        // Other users section
        if (otherUsers.isNotEmpty) ...[
          if (staffUsers.isNotEmpty) _buildCategoryHeader('Members', otherUsers.length, scheme),
          if (staffUsers.isNotEmpty) const SizedBox(height: 8),
          ...otherUsers.map((user) => _buildMemberCard(user, scheme)),
        ],
      ],
    );
  }

  Widget _buildCategoryHeader(String title, int count, ColorScheme scheme) {
    return Row(
      children: [
        Icon(
          title == 'Staff' ? Icons.admin_panel_settings : Icons.people_outline,
          color: scheme.primary,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          '$title ($count)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: scheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildMemberCard(GroupUser user, ColorScheme scheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _buildUserAvatar(user, scheme),
        title: Text(
          user.username,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${user.id}'),
            Text('Category: ${user.category}'),
            if (user.status.isNotEmpty)
              Text('Status: ${user.status}'),
          ],
        ),
        trailing: user.isAdmin
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Admin',
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
