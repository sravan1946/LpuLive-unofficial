class Contact {
  final String userid;
  final String? avatar;
  final String name;
  final String? userimageurl;
  final String category;

  Contact({
    required this.userid,
    this.avatar,
    required this.name,
    this.userimageurl,
    required this.category,
  });

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
