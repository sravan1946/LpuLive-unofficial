class SenderNameUtils {
  /// Parse the sender name to extract just the username part
  /// Format is typically "Username : UserID" or just "Username"
  static String parseSenderName(String senderName) {
    if (senderName.isEmpty) return 'Unknown';

    final colonIndex = senderName.indexOf(' : ');
    if (colonIndex != -1) {
      return senderName.substring(0, colonIndex).trim();
    }
    return senderName;
  }
}
