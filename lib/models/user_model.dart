// Authenticated user profile and permissions.

// Flutter imports:
import 'package:flutter/foundation.dart';

// Project imports:
import 'group_model.dart';

class User {
  /// Token used to authenticate chat requests.
  final String chatToken;

  /// Raw name string as provided by backend, often "displayName : id".
  final String name;

  /// Extracted display name portion of [name].
  final String displayName;

  /// Extracted user id portion of [name].
  final String id;

  /// Department name.
  final String department;

  /// User category (e.g., Student/Faculty).
  final String category;

  /// Optional URL to user's profile image.
  final String? userImageUrl;

  /// Groups the user is a member of.
  final List<Group> groups;

  /// Whether the user can create groups.
  final bool createGroups;

  /// Whether one-to-one chats are enabled for this user.
  final bool oneToOne;

  /// Whether the user's chat privileges are suspended.
  final bool isChatSuspended;

  /// Creates a [User].
  User({
    required this.chatToken,
    required this.name,
    required this.displayName,
    required this.id,
    required this.department,
    required this.category,
    this.userImageUrl,
    required this.groups,
    required this.createGroups,
    required this.oneToOne,
    required this.isChatSuspended,
  });

  /// Parses a [User] from JSON, handling group array/object variants.
  factory User.fromJson(Map<String, dynamic> json) {
    final chatToken = json['ChatToken'] ?? '';
    final name = json['Name'] ?? '';
    final department = json['Department'] ?? '';
    final category = json['Category'] ?? '';
    final userImageUrl = json['UserImageUrl'];
    final groups = json['Groups'] ?? [];
    final createGroups = json['CreateGroups'] ?? false;
    final oneToOne = json['OneToOne'] ?? false;
    final isChatSuspended = json['IsChatSuspended'] ?? false;

    // Handle groups - can be either objects or arrays depending on the endpoint
    List<Group> parsedGroups = [];
    if (groups is List<dynamic>) {
      debugPrint('🔍 [User.fromJson] Processing ${groups.length} groups');
      for (int i = 0; i < groups.length; i++) {
        final group = groups[i];
        debugPrint('🔍 [User.fromJson] Group $i type: ${group.runtimeType}');
        if (group is Map<String, dynamic>) {
          // Object format (from regular endpoints)
          debugPrint('🔍 [User.fromJson] Parsing group $i as object');
          parsedGroups.add(Group.fromJson(group));
        } else if (group is List<dynamic>) {
          // Array format (from authorize endpoint)
          debugPrint('🔍 [User.fromJson] Parsing group $i as array: $group');
          parsedGroups.add(Group.fromArray(group));
        } else {
          debugPrint(
            '⚠️ [User.fromJson] Unknown group format: ${group.runtimeType} - $group',
          );
        }
      }
    } else {
      debugPrint(
        '⚠️ [User.fromJson] Groups is not a List: ${groups.runtimeType}',
      );
    }

    return User(
      chatToken: chatToken,
      name: name,
      displayName: name.contains(' : ') ? name.split(' : ')[0] : name,
      id: name.contains(' : ') ? name.split(' : ')[1] : name,
      department: department,
      category: category,
      userImageUrl: userImageUrl,
      groups: parsedGroups,
      createGroups: createGroups,
      oneToOne: oneToOne,
      isChatSuspended: isChatSuspended,
    );
  }

  /// Serializes this [User] to JSON.
  Map<String, dynamic> toJson() {
    return {
      'ChatToken': chatToken,
      'Name': name,
      'Department': department,
      'Category': category,
      'UserImageUrl': userImageUrl,
      'Groups': groups.map((group) => group.toJson()).toList(),
      'CreateGroups': createGroups,
      'OneToOne': oneToOne,
      'IsChatSuspended': isChatSuspended,
    };
  }
}
