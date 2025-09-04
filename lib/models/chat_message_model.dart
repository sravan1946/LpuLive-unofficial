import 'current_user_state.dart';

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


