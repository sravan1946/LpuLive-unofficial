class GroupUser {
  final String id;
  final String avatar;
  final String username;
  final String category;
  final bool isAdmin;
  final String status;

  GroupUser({
    required this.id,
    required this.avatar,
    required this.username,
    required this.category,
    required this.isAdmin,
    required this.status,
  });

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

class GroupDetails {
  final List<GroupUser> users;
  final bool twoWayStatus;
  final bool isOneToOne;

  GroupDetails({
    required this.users,
    required this.twoWayStatus,
    required this.isOneToOne,
  });

  factory GroupDetails.fromJson(Map<String, dynamic> json) {
    final usersList = json['users'] as List<dynamic>? ?? [];
    final users = usersList.map((userJson) => GroupUser.fromJson(userJson)).toList();
    
    return GroupDetails(
      users: users,
      twoWayStatus: json['two_way_status'] == true,
      isOneToOne: json['is_one_to_one'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'users': users.map((user) => user.toJson()).toList(),
      'two_way_status': twoWayStatus,
      'is_one_to_one': isOneToOne,
    };
  }
}

