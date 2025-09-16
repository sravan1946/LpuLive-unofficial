/// Defines the core chat message model, including optional media and reply data.
import 'current_user_state.dart';

/// Represents a chat message with sender, time, and optional media/reply info.
class ChatMessage {
  /// Unique message identifier.
  final String id;

  /// Message text content.
  final String message;

  /// Sender user ID.
  final String sender;

  /// Human-friendly sender name.
  final String senderName;

  /// Original timestamp string from backend.
  final String timestamp;

  /// True if the message was sent by the current user.
  final bool isOwnMessage;

  /// Optional URL or path of sender avatar image.
  final String? userImage;

  /// Optional sender category (e.g. student/faculty).
  final String? category;

  /// Optional group identifier the message belongs to.
  final String? group;

  /// Optional media identifier attached to the message.
  final String? mediaId;

  /// Optional media original name.
  final String? mediaName;

  /// Optional media MIME-like type.
  final String? mediaType;

  /// Optional normalized media URL (points to backend/media/.../).
  final String? mediaUrl;

  // Reply fields

  /// Optional message ID being replied to.
  final String? replyMessageId;

  /// Optional reply visibility/type (e.g. private).
  final String? replyType;

  /// Optional reply message content.
  final String? replyMessage;

  /// Optional user ID targeted in a private reply.
  final String? replyUserId;

  /// Creates a [ChatMessage].
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
    this.replyMessageId,
    this.replyType,
    this.replyMessage,
    this.replyUserId,
  });

  /// Parses a [ChatMessage] from backend JSON.
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
        // Always point to backend/media/{segment}/ (trailing slash required)
        const backendBase = 'https://lpulive.lpu.in/backend';
        String segment;
        final idx = rawUrl.indexOf('/media/');
        if (idx != -1) {
          segment = rawUrl.substring(idx + '/media/'.length);
        } else {
          segment = rawUrl.replaceFirst(RegExp(r'^/+'), '');
        }
        // Strip any trailing slashes from segment, then append one
        segment = segment.replaceAll(RegExp(r'/+$'), '');
        mUrl = '$backendBase/media/$segment/';
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
      replyMessageId: json['reply_message_id']?.toString(),
      replyType: json['privateReply']?.toString(),
      replyMessage: json['private_reply_message']?.toString(),
      replyUserId: json['private_reply_userid']?.toString(),
    );
  }
}
