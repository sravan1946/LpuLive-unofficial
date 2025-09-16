// Aggregates chat messages for a given course section.
import 'chat_message_model.dart';

class CourseGroup {
  /// Human-readable course name.
  final String courseName;

  /// Unique course code.
  final String courseCode;

  /// Messages loaded for this course group.
  final List<ChatMessage> messages;

  /// UI loading flag for this group's messages.
  final bool isLoading;

  /// Timestamp string of the most recent message.
  final String lastMessageTime;

  /// Creates a [CourseGroup].
  CourseGroup({
    required this.courseName,
    required this.courseCode,
    required this.messages,
    this.isLoading = false,
    this.lastMessageTime = '',
  });

  /// Returns a copy with provided fields replaced.
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
