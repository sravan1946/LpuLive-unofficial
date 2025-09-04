/// Utility class for parsing and handling timestamps in various formats
class TimestampUtils {
  /// Parses a timestamp string, supporting both ISO 8601 and human-readable formats
  static DateTime? parseTimestamp(String timestamp) {
    // Handle empty, whitespace-only, or null timestamps
    if (timestamp.trim().isEmpty) {
      return null;
    }

    final trimmed = timestamp.trim();

    // First try ISO 8601 parsing
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      return parsed;
    }

    // Try to parse human-readable formats
    return _parseHumanReadableTimestamp(trimmed);
  }

  /// Parses human-readable timestamp formats like "Today 11:05 AM", "Yesterday 07:55 PM", etc.
  static DateTime? _parseHumanReadableTimestamp(String timestamp) {
    final now = DateTime.now();
    final lowerTimestamp = timestamp.toLowerCase();

    // Handle "Today" format: "Today 11:05 AM"
    if (lowerTimestamp.startsWith('today')) {
      final timePart = timestamp.substring(5).trim(); // Remove "Today"
      final time = _parseTimeString(timePart);
      if (time != null) {
        return DateTime(now.year, now.month, now.day, time.hour, time.minute);
      }
    }

    // Handle "Yesterday" format: "Yesterday 07:55 PM"
    if (lowerTimestamp.startsWith('yesterday')) {
      final timePart = timestamp.substring(9).trim(); // Remove "Yesterday"
      final time = _parseTimeString(timePart);
      if (time != null) {
        final yesterday = now.subtract(const Duration(days: 1));
        return DateTime(yesterday.year, yesterday.month, yesterday.day, time.hour, time.minute);
      }
    }

    // Handle day names: "Tuesday 11:05 AM", "Monday 09:15 AM", etc.
    final dayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    for (int i = 0; i < dayNames.length; i++) {
      if (lowerTimestamp.startsWith(dayNames[i])) {
        final timePart = timestamp.substring(dayNames[i].length).trim();
        final time = _parseTimeString(timePart);
        if (time != null) {
          // Calculate which day of the week this refers to
          final targetWeekday = i + 1; // Monday = 1, Sunday = 7
          final currentWeekday = now.weekday; // Monday = 1, Sunday = 7

          int daysToSubtract = currentWeekday - targetWeekday;
          if (daysToSubtract < 0) {
            daysToSubtract += 7; // Go back to previous week
          }

          final targetDate = now.subtract(Duration(days: daysToSubtract));
          return DateTime(targetDate.year, targetDate.month, targetDate.day, time.hour, time.minute);
        }
      }
    }

    return null;
  }

  /// Parses time strings in 12-hour format with AM/PM (e.g., "11:05 AM", "3:30 PM")
  static DateTime? _parseTimeString(String timeString) {
    // Parse time formats like "11:05 AM", "07:55 PM", "3:30 PM", etc.
    final timeRegex = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false);
    final match = timeRegex.firstMatch(timeString.trim());

    if (match != null) {
      final hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final period = match.group(3)!.toUpperCase();

      int hour24 = hour;
      if (period == 'PM' && hour != 12) {
        hour24 = hour + 12;
      } else if (period == 'AM' && hour == 12) {
        hour24 = 0;
      }

      if (hour24 >= 0 && hour24 <= 23 && minute >= 0 && minute <= 59) {
        return DateTime(0, 1, 1, hour24, minute); // Year/month/day don't matter for time-only
      }
    }

    return null;
  }
}