/// Lightweight contact entry used for selections and listings.
class Contact {
  /// Unique user identifier.
  final String userid;

  /// Optional avatar short code or URL.
  final String? avatar;

  /// Display name of the user.
  final String name;

  /// Optional absolute URL to user image.
  final String? userimageurl;

  /// User category (e.g. Student/Faculty).
  final String category;

  /// Creates a [Contact].
  Contact({
    required this.userid,
    this.avatar,
    required this.name,
    this.userimageurl,
    required this.category,
  });

  /// Parses a [Contact] from JSON.
  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      userid: json['userid'] ?? '',
      avatar: json['avatar'],
      name: json['name'] ?? '',
      userimageurl: json['userimageurl'],
      category: json['category'] ?? '',
    );
  }
}
