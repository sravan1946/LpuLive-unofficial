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


