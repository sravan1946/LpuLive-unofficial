import '../models/message_status.dart';
import '../models/chat_message_model.dart';

class MessageStatusService {
  final Map<String, MessageStatus> _messageStatuses = {};

  Map<String, MessageStatus> get messageStatuses => _messageStatuses;

  void setStatus(String messageId, MessageStatus status) {
    _messageStatuses[messageId] = status;
  }

  MessageStatus getStatus(String messageId) {
    return _messageStatuses[messageId] ?? MessageStatus.sent;
  }

  void removeStatus(String messageId) {
    _messageStatuses.remove(messageId);
  }

  void initializeStatuses(List<ChatMessage> messages) {
    for (final message in messages) {
      _messageStatuses[message.id] = MessageStatus.sent;
    }
  }

  void clear() {
    _messageStatuses.clear();
  }

  /// Check if a message is a server acknowledgment of a local message
  int findLocalMessageIndex(
    List<ChatMessage> messages,
    ChatMessage serverMessage,
  ) {
    return messages.indexWhere(
      (existingMessage) =>
          existingMessage.id.startsWith('local-') &&
          existingMessage.message == serverMessage.message &&
          existingMessage.sender == serverMessage.sender &&
          _messageStatuses[existingMessage.id] == MessageStatus.sending,
    );
  }

  /// Update local message with server data and update status
  void updateLocalMessageWithServerData(
    List<ChatMessage> messages,
    int localMessageIndex,
    ChatMessage serverMessage,
  ) {
    if (localMessageIndex != -1) {
      messages[localMessageIndex] = serverMessage;
      _messageStatuses[serverMessage.id] = MessageStatus.sent;
      _messageStatuses.remove(
        messages[localMessageIndex].id,
      ); // Remove old local ID
    }
  }
}
