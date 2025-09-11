import 'package:shared_preferences/shared_preferences.dart';

class ConversationReadTracker {
  static String _key(String conversationId) => 'last_read_ts_$conversationId';

  static Future<DateTime?> getLastReadAt(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_key(conversationId));
    if (iso == null || iso.isEmpty) return null;
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setLastReadToNow(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(conversationId), DateTime.now().toIso8601String());
  }

  static Future<void> setLastReadTo(String conversationId, String isoTs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(conversationId), isoTs);
  }
}

class OpenConversations {
  static final Set<String> _open = <String>{};

  static void open(String conversationId) {
    _open.add(conversationId);
  }

  static void close(String conversationId) {
    _open.remove(conversationId);
  }

  static bool isOpen(String conversationId) => _open.contains(conversationId);
}


