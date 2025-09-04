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
      groupLastMessage: json['groupLastMessage'] ?? json['lastMessage'] ?? '',
      lastMessageTime: json['lastMessageTime'] ?? json['timestamp'] ?? '',
      isActive: json['isActive'] ?? false,
      isAdmin: json['isAdmin'] ?? false,
      inviteStatus: json['inviteStatus'] ?? '',
      isTwoWay: json['isTwoWay'] ?? false,
      isOneToOne: json['isOneToOne'] ?? false,
    );
  }

  Group copyWith({
    String? name,
    String? groupLastMessage,
    String? lastMessageTime,
    bool? isActive,
    bool? isAdmin,
    String? inviteStatus,
    bool? isTwoWay,
    bool? isOneToOne,
  }) {
    return Group(
      name: name ?? this.name,
      groupLastMessage: groupLastMessage ?? this.groupLastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      isActive: isActive ?? this.isActive,
      isAdmin: isAdmin ?? this.isAdmin,
      inviteStatus: inviteStatus ?? this.inviteStatus,
      isTwoWay: isTwoWay ?? this.isTwoWay,
      isOneToOne: isOneToOne ?? this.isOneToOne,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'groupLastMessage': groupLastMessage,
      'lastMessageTime': lastMessageTime,
      'isActive': isActive,
      'isAdmin': isAdmin,
      'inviteStatus': inviteStatus,
      'isTwoWay': isTwoWay,
      'isOneToOne': isOneToOne,
    };
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
  final String? group;

  ChatMessage({
    required this.id,
    required this.message,
    required this.sender,
    required this.senderName,
    required this.timestamp,
    required this.isOwnMessage,
    this.userImage,
    this.category,
    this.group,
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
      group: json['group'] ?? '',
    );
  }
}

class CourseGroup {
  final String courseName;
  final String courseCode;
  final List<ChatMessage> messages;
  final bool isLoading;
  final String lastMessageTime;

  CourseGroup({
    required this.courseName,
    required this.courseCode,
    required this.messages,
    this.isLoading = false,
    this.lastMessageTime = '',
  });

  CourseGroup copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? lastMessageTime,
  }) {
    return CourseGroup(
      courseName: courseName,
      courseCode: courseCode,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
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

  DirectMessage copyWith({
    String? dmName,
    String? participants,
    String? lastMessage,
    String? lastMessageTime,
    bool? isActive,
    bool? isAdmin,
  }) {
    return DirectMessage(
      dmName: dmName ?? this.dmName,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      isActive: isActive ?? this.isActive,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}

class Contact {
  final String userid;
  final String? avatar;
  final String name;
  final String? userimageurl;
  final String category;

  Contact({
    required this.userid,
    this.avatar,
    required this.name,
    this.userimageurl,
    required this.category,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      userid: json['userid'] ?? '',
      avatar: json['avatar'],
      name: json['name'] ?? '',
      userimageurl: json['userimageurl'],
      category: json['category'] ?? '',
    );
  }
}

class SearchResult {
  final String message;
  final String? category;
  final String? regID;
  final String? error;

  SearchResult({
    required this.message,
    this.category,
    this.regID,
    this.error,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      message: json['message'] ?? '',
      category: json['category'],
      regID: json['regID'],
      error: json['error'],
    );
  }

  bool get isSuccess => error == null;
}

class CreateGroupResult {
  final String statusCode;
  final String message;
  final String? name;
  final dynamic data;

  CreateGroupResult({
    required this.statusCode,
    required this.message,
    this.name,
    this.data,
  });

  factory CreateGroupResult.fromJson(Map<String, dynamic> json) {
    return CreateGroupResult(
      statusCode: json['statusCode'] ?? '',
      message: json['message'] ?? '',
      name: json['name'],
      data: json['data'],
    );
  }

  bool get isSuccess => statusCode == '200';
}

// Global variable to store parsed token data
User? currentUser;