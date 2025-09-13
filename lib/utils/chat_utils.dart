class ChatUtils {
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String dateLabelFor(String isoTs) {
    try {
      final date = DateTime.parse(isoTs);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(date.year, date.month, date.day);
      
      if (messageDate == today) {
        return 'Today';
      } else if (messageDate == today.subtract(const Duration(days: 1))) {
        return 'Yesterday';
      } else if (messageDate.isAfter(today.subtract(const Duration(days: 7)))) {
        return _getDayName(date.weekday);
      } else {
        return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  static bool isDifferentCalendarDay(String prevIso, String curIso) {
    try {
      final prev = DateTime.parse(prevIso);
      final cur = DateTime.parse(curIso);
      return !isSameDay(prev, cur);
    } catch (e) {
      return true;
    }
  }

  static String formatTimestamp(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inMinutes < 1) {
        return 'now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d';
      } else {
        return '${_getMonthName(date.month)} ${date.day}';
      }
    } catch (e) {
      return '';
    }
  }

  static String _getDayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  static String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
