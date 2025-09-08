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
  final String? mediaId;
  final String? mediaName;
  final String? mediaType;
  final String? mediaUrl;

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
    this.mediaId,
    this.mediaName,
    this.mediaType,
    this.mediaUrl,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final userId = json['Id']?.toString() ?? '';
    final currentUserId = currentUser?.id ?? '';

    // Media (optional)
    String? mId;
    String? mName;
    String? mType;
    String? mUrl;
    final media = json['media'];
    if (media is Map<String, dynamic>) {
      mId = media['id']?.toString();
      mName = media['name']?.toString();
      mType = media['type']?.toString();
      final rawUrl = media['url']?.toString();
      if (rawUrl != null && rawUrl.isNotEmpty) {
        // Prefix relative URLs with site origin
        if (rawUrl.startsWith('http')) {
          mUrl = rawUrl;
        } else {
          mUrl = 'https://lpulive.lpu.in$rawUrl';
        }
      }
    }

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
      mediaId: mId,
      mediaName: mName,
      mediaType: mType,
      mediaUrl: mUrl,
    );
  }
}


