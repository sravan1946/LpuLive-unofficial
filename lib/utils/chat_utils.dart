// Project imports:
import '../models/user_models.dart';

class ChatUtils {
  static String formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final hh = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final mm = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hh:$mm $ampm';
    } catch (e) {
      return timestamp;
    }
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String dateLabelFor(String isoTs) {
    DateTime dt;
    try {
      dt = DateTime.parse(isoTs).toLocal();
    } catch (_) {
      return '';
    }
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    if (isSameDay(dt, now)) return 'Today';
    if (isSameDay(dt, yesterday)) return 'Yesterday';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  static bool isDifferentCalendarDay(String prevIso, String curIso) {
    try {
      final p = DateTime.parse(prevIso).toLocal();
      final c = DateTime.parse(curIso).toLocal();
      return !isSameDay(p, c);
    } catch (_) {
      return false;
    }
  }

  // In ascending _messages list, determine whether to show a date header before index
  static bool shouldShowDateHeaderBefore(
    List<ChatMessage> messages,
    int index,
  ) {
    if (messages.isEmpty) return false;
    if (index <= 0) return true; // show header before the first item
    final prevTs = messages[index - 1].timestamp;
    final curTs = messages[index].timestamp;
    return isDifferentCalendarDay(prevTs, curTs);
  }

  // Determine where to show the unread divider based on last read timestamp
  static int? unreadDividerIndex(
    List<ChatMessage> messages,
    DateTime? lastReadAt,
  ) {
    if (messages.isEmpty) return null;

    // If we don't have a last-read marker (first open), treat all messages from others as unread
    // and place the divider before the first non-own message, if any.
    if (lastReadAt == null) {
      for (int i = 0; i < messages.length; i++) {
        if (!messages[i].isOwnMessage) return i;
      }
      return null; // only own messages exist
    }

    // Find first message at-or-newer than lastRead (handle equal timestamps)
    for (int i = 0; i < messages.length; i++) {
      try {
        final ts = DateTime.parse(messages[i].timestamp);
        // Only consider messages from others as unread
        if ((ts.isAfter(lastReadAt) || ts.isAtSameMomentAs(lastReadAt)) &&
            !messages[i].isOwnMessage) {
          // Place divider before this message
          return i;
        }
      } catch (_) {
        // ignore parse errors
      }
    }
    return null;
  }
}
