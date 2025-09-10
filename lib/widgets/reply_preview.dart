import 'package:flutter/material.dart';
import '../models/chat_message_model.dart';

class ReplyPreview extends StatelessWidget {
  final ChatMessage message;
  final bool isOwn;
  final List<ChatMessage> allMessages;

  const ReplyPreview({
    super.key,
    required this.message,
    required this.isOwn,
    required this.allMessages,
  });

  String _getReplySenderName() {
    if (message.replyUserId == null) return 'Unknown';
    
    // Find the original message by ID
    final originalMessage = allMessages.firstWhere(
      (m) => m.id == message.replyMessageId,
      orElse: () => ChatMessage(
        id: '',
        message: '',
        sender: '',
        senderName: '',
        timestamp: '',
        isOwnMessage: false,
      ),
    );
    
    // If we found the original message, parse its sender name
    if (originalMessage.id.isNotEmpty && originalMessage.senderName.isNotEmpty) {
      // Parse the sender name to extract just the username part
      // Format is typically "Username : UserID" or just "Username"
      final senderName = originalMessage.senderName;
      final colonIndex = senderName.indexOf(' : ');
      if (colonIndex != -1) {
        return senderName.substring(0, colonIndex).trim();
      }
      return senderName;
    }
    
    // Fallback to user ID if we can't find the original message
    return message.replyUserId!;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isOwn 
            ? scheme.onPrimary.withValues(alpha: 0.1)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOwn 
              ? scheme.onPrimary.withValues(alpha: 0.3)
              : scheme.outline,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 30,
            decoration: BoxDecoration(
              color: isOwn ? scheme.onPrimary : scheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${_getReplySenderName()}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isOwn ? scheme.onPrimary : scheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.replyMessage ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOwn 
                        ? scheme.onPrimary.withValues(alpha: 0.8)
                        : scheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
