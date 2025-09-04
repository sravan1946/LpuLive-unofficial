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

    return User(
      chatToken: chatToken,
      name: name,
      displayName: name,
      id: name.contains(' : ') ? name.split(' : ')[1] : name,
      department: department,
      category: category,
      userImageUrl: userImageUrl,
      groups: (groups as List<dynamic>)
          .map((group) => Group.fromJson(group))
          .toList(),
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


