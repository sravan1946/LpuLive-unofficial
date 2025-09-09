import 'chat_message_model.dart';

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
