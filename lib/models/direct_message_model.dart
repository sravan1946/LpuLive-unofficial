/// Metadata for a direct message conversation.
class DirectMessage {
  /// Display name for the DM thread.
  final String dmName;

  /// Comma-separated participant identifiers.
  final String participants;

  /// Last message preview text.
  final String lastMessage;

  /// Timestamp of the last message.
  final String lastMessageTime;

  /// Whether the DM is currently active/enabled.
  final bool isActive;

  /// Whether the current user has admin privileges.
  final bool isAdmin;

  /// Creates a [DirectMessage].
  DirectMessage({
    required this.dmName,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.isActive,
    required this.isAdmin,
  });

  /// Returns a copy with provided fields replaced.
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
