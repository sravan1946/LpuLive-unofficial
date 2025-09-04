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


