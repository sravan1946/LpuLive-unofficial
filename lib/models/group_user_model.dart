/// Represents a member of a group with role and presence info.
class GroupUser {
  /// User identifier.
  final String id;

  /// Avatar short code or URL.
  final String avatar;

  /// Displayable username.
  final String username;

  /// User category/role.
  final String category;

  /// True if the user is group admin.
  final bool isAdmin;

  /// Membership status string.
  final String status;

  /// Creates a [GroupUser].
  GroupUser({
    required this.id,
    required this.avatar,
    required this.username,
    required this.category,
    required this.isAdmin,
    required this.status,
  });

  /// Parses a [GroupUser] from JSON.
  factory GroupUser.fromJson(Map<String, dynamic> json) {
    return GroupUser(
      id: json['id']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      isAdmin: json['isAdmin'] == true,
      status: json['status']?.toString() ?? '',
    );
  }

  /// Serializes this [GroupUser] to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'avatar': avatar,
      'username': username,
      'category': category,
      'isAdmin': isAdmin,
      'status': status,
    };
  }
}

/// Group-level details including member list and communication flags.
class GroupDetails {
  /// Members of the group.
  final List<GroupUser> users;

  /// Whether two-way communication is enabled.
  final bool twoWayStatus;

  /// True if the group is a 1:1 conversation.
  final bool isOneToOne;

  /// Creates a [GroupDetails].
  GroupDetails({
    required this.users,
    required this.twoWayStatus,
    required this.isOneToOne,
  });

  /// Parses a [GroupDetails] from JSON.
  factory GroupDetails.fromJson(Map<String, dynamic> json) {
    final usersList = json['users'] as List<dynamic>? ?? [];
    final users = usersList
        .map((userJson) => GroupUser.fromJson(userJson))
        .toList();

    return GroupDetails(
      users: users,
      twoWayStatus: json['two_way_status'] == true,
      isOneToOne: json['is_one_to_one'] == true,
    );
  }

  /// Serializes this [GroupDetails] to JSON.
  Map<String, dynamic> toJson() {
    return {
      'users': users.map((user) => user.toJson()).toList(),
      'two_way_status': twoWayStatus,
      'is_one_to_one': isOneToOne,
    };
  }
}
