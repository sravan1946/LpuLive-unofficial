import 'package:flutter/material.dart';
import '../models/user_models.dart';
import '../services/chat_services.dart';
import '../widgets/app_toast.dart';

class NewDMPage extends StatefulWidget {
  const NewDMPage({super.key});

  @override
  State<NewDMPage> createState() => _NewDMPageState();
}

class _NewDMPageState extends State<NewDMPage> {
  final ChatApiService _apiService = ChatApiService();
  final TextEditingController _searchController = TextEditingController();

  List<Contact> _contacts = [];
  bool _isLoadingContacts = true;
  bool _isSearching = false;
  Contact? _selectedContact;

  @override
  void initState() {
    super.initState();
    print('🚀 [NewDMPage] New DM page initialized - USING PRINT');
    debugPrint('🚀 [NewDMPage] New DM page initialized - USING DEBUGPRINT');
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    if (currentUser == null) return;

    setState(() {
      _isLoadingContacts = true;
    });

    try {
      debugPrint('🔄 [NewDMPage] Fetching contacts...');
      debugPrint('📤 [NewDMPage] Request: POST /api/groups/contacts');
      debugPrint(
        '📤 [NewDMPage] Request Body: {"ChatToken": "${currentUser!.chatToken}"}',
      );

      final contacts = await _apiService.fetchContacts(currentUser!.chatToken);

      debugPrint(
        '📥 [NewDMPage] Response: ${contacts.length} contacts received',
      );
      debugPrint(
        '📥 [NewDMPage] Response Data: ${contacts.map((c) => {"userid": c.userid, "name": c.name, "category": c.category}).toList()}',
      );

      if (mounted && contacts.isNotEmpty) {
        showAppToast(
          context,
          'Loaded ${contacts.length} contacts',
          type: ToastType.success,
          duration: const Duration(seconds: 2),
        );
      }

      setState(() {
        _contacts = contacts;
        _isLoadingContacts = false;
      });
    } catch (e) {
      debugPrint('❌ [NewDMPage] Error fetching contacts: $e');
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

  Future<void> _searchUser() async {
    final regID = _searchController.text.trim();
    if (regID.isEmpty || currentUser == null) return;

    setState(() {
      _isSearching = true;
    });

    try {
      debugPrint('🔍 [NewDMPage] Searching user...');
      debugPrint('📤 [NewDMPage] Request: POST /api/groups/searchuser');
      debugPrint(
        '📤 [NewDMPage] Request Body: {"ChatToken": "${currentUser!.chatToken}", "regID": "$regID"}',
      );

      final result = await _apiService.searchUser(
        currentUser!.chatToken,
        regID,
      );

      debugPrint('📥 [NewDMPage] Search Response: ${result.toString()}');
      debugPrint(
        '📥 [NewDMPage] Response Data: {"message": "${result.message}", "category": "${result.category}", "regID": "${result.regID}", "error": "${result.error}"}',
      );

      if (result.isSuccess && result.regID != null) {
        // Create a contact from search result
        final searchContact = Contact(
          userid: result.regID!,
          name: '$regID : ${result.regID}',
          category: result.category ?? 'Student',
        );

        debugPrint('✅ [NewDMPage] User found: ${searchContact.name}');

        if (mounted) {
          showAppToast(
            context,
            'User found: ${searchContact.name}',
            type: ToastType.success,
          );
        }

        setState(() {
          _selectedContact = searchContact;
          _isSearching = false;
        });
      } else {
        debugPrint(
          '❌ [NewDMPage] User not found: ${result.error ?? result.message}',
        );
        if (mounted) {
          showAppToast(
            context,
            result.error ?? 'User not found',
            type: ToastType.error,
          );
        }
        setState(() {
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [NewDMPage] Search error: $e');

      // Extract the actual error message from the exception
      String errorMessage = e.toString();

      // Check if it's the specific API error message
      if (errorMessage.contains(
        "User doesn't exist in LPU Live or Hasn't Logged In Yet",
      )) {
        if (mounted) {
          showAppToast(
            context,
            "User doesn't exist in LPU Live or Hasn't Logged In Yet",
            type: ToastType.error,
          );
        }
        setState(() {
          _isSearching = false;
        });
      } else if (errorMessage.contains('Failed to search user: 404')) {
        // This is likely the user not found case
        if (mounted) {
          showAppToast(
            context,
            "User doesn't exist in LPU Live or Hasn't Logged In Yet",
            type: ToastType.error,
          );
        }
        setState(() {
          _isSearching = false;
        });
      } else {
        // Handle other search errors
        if (mounted) {
          showAppToast(
            context,
            'Oops! Something went wrong while searching. Please check your connection and try again.',
            type: ToastType.error,
          );
        }
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _createDM() async {
    if (_selectedContact == null || currentUser == null) return;

    try {
      final groupName = '${currentUser!.id} : ${_selectedContact!.userid}';

      debugPrint('🚀 [NewDMPage] Creating DM...');
      debugPrint('📤 [NewDMPage] Request: POST /api/groups/create');
      debugPrint(
        '📤 [NewDMPage] Request Body: {"ChatToken": "${currentUser!.chatToken}", "GroupName": "$groupName", "is_two_way": "", "Members": "${_selectedContact!.userid}", "one_To_One": true}',
      );

      final result = await _apiService.createGroup(
        currentUser!.chatToken,
        groupName,
        _selectedContact!.userid,
      );

      debugPrint('📥 [NewDMPage] Create DM Response: ${result.toString()}');
      debugPrint(
        '📥 [NewDMPage] Response Data: {"statusCode": "${result.statusCode}", "message": "${result.message}", "name": "${result.name}", "data": ${result.data}}',
      );

      if (result.isSuccess) {
        debugPrint('✅ [NewDMPage] DM created successfully: ${result.name}');
        if (mounted) {
          showAppToast(
            context,
            'DM created successfully!',
            type: ToastType.success,
          );
          Navigator.of(context).pop(true); // Return true to indicate success
        }
      } else {
        debugPrint('❌ [NewDMPage] Failed to create DM: ${result.message}');
        if (mounted) {
          showAppToast(
            context,
            'Failed to create DM: ${result.message}',
            type: ToastType.error,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ [NewDMPage] Error creating DM: $e');

      // Handle specific case where group already exists
      if (e.toString().contains('Group Already exists') ||
          e.toString().contains('400')) {
        if (mounted) {
          showAppToast(
            context,
            'DM already exists with this user!',
            type: ToastType.warning,
          );
          // Still navigate back as success since the DM exists
          Navigator.of(context).pop(true);
        }
      } else {
        // Handle other errors normally
        if (mounted) {
          showAppToast(context, 'Error creating DM: $e', type: ToastType.error);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start New Conversation'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search section with improved design
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Find Someone',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText:
                              'Enter Registration Number (e.g., 12345678)',
                          hintStyle: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        onSubmitted: (_) => _searchUser(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: _isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      onPressed: _isSearching ? null : _searchUser,
                      tooltip: 'Search User',
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Selected user display with improved design
          if (_selectedContact != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      _selectedContact!.name.isNotEmpty
                          ? _selectedContact!.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedContact!.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedContact!.category,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _createDM,
                    icon: const Icon(Icons.message, size: 16),
                    label: const Text('Start Chat'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Contacts list with improved design
          Expanded(
            child: _isLoadingContacts
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading your contacts...',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No contacts available',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try searching for someone above',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
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
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Recent Contacts',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_contacts.length}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _contacts.length,
                          itemBuilder: (context, index) {
                            final contact = _contacts[index];
                            final isSelected =
                                _selectedContact?.userid == contact.userid;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: isSelected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : null,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  child: Text(
                                    contact.name.isNotEmpty
                                        ? contact.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  contact.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  contact.category,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check_circle,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        size: 24,
                                      )
                                    : Icon(
                                        Icons.arrow_forward_ios,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        size: 16,
                                      ),
                                onTap: () {
                                  setState(() {
                                    _selectedContact = contact;
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
    );
  }
}
