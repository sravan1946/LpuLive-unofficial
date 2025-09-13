import 'package:flutter/foundation.dart';
import 'group_model.dart';

class User {
  final String chatToken;
  final String name;
  final String displayName;
  final String id;
  final String department;
  final String category;
  final String? userImageUrl;
  final List<Group> groups;
  final bool createGroups;
  final bool oneToOne;
  final bool isChatSuspended;

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

    // Handle groups - they can be either objects or arrays depending on the endpoint
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
          debugPrint('⚠️ [User.fromJson] Unknown group format: ${group.runtimeType} - $group');
        }
      }
    } else {
      debugPrint('⚠️ [User.fromJson] Groups is not a List: ${groups.runtimeType}');
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
