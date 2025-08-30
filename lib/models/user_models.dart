// Token data models
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
    // Handle different possible key names
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
}

class Group {
  final String name;
  final String groupLastMessage;
  final String lastMessageTime;
  final bool isActive;
  final bool isAdmin;
  final String inviteStatus;
  final bool isTwoWay;
  final bool isOneToOne;

  Group({
    required this.name,
    required this.groupLastMessage,
    required this.lastMessageTime,
    required this.isActive,
    required this.isAdmin,
    required this.inviteStatus,
    required this.isTwoWay,
    required this.isOneToOne,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      name: json['name'] ?? '',
      groupLastMessage: json['groupLastMessage'] ?? '',
      lastMessageTime: json['lastMessageTime'] ?? '',
      isActive: json['isActive'] ?? false,
      isAdmin: json['isAdmin'] ?? false,
      inviteStatus: json['inviteStatus'] ?? '',
      isTwoWay: json['isTwoWay'] ?? false,
      isOneToOne: json['isOneToOne'] ?? false,
    );
  }
}

class ChatMessage {
  final String id;
  final String message;
  final String sender;
  final String senderName;
  final String timestamp;
  final bool isOwnMessage;
  final String? userImage;
  final String? category;

  ChatMessage({
    required this.id,
    required this.message,
    required this.sender,
    required this.senderName,
    required this.timestamp,
    required this.isOwnMessage,
    this.userImage,
    this.category,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final userId = json['Id']?.toString() ?? '';
    final currentUserId = currentUser?.id ?? '';

    return ChatMessage(
      id: json['message_id']?.toString() ?? '',
      message: json['message'] ?? '',
      sender: userId,
      senderName: json['UserName'] ?? '',
      timestamp: json['DateAndTime'] ?? '',
      isOwnMessage: userId == currentUserId,
      userImage: json['UserImage'],
      category: json['Category'],
    );
  }
}

class CourseGroup {
  final String courseName;
  final String courseCode;
  final List<ChatMessage> messages;
  final bool isLoading;

  CourseGroup({
    required this.courseName,
    required this.courseCode,
    required this.messages,
    this.isLoading = false,
  });

  CourseGroup copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
  }) {
    return CourseGroup(
      courseName: courseName,
      courseCode: courseCode,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DirectMessage {
  final String dmName;
  final String participants;
  final String lastMessage;
  final String lastMessageTime;
  final bool isActive;
  final bool isAdmin;

  DirectMessage({
    required this.dmName,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.isActive,
    required this.isAdmin,
  });
}

// Global variable to store parsed token data
User? currentUser;