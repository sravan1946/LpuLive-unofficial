class SearchResult {
  final String message;
  final String? category;
  final String? regID;
  final String? error;

  SearchResult({
    required this.message,
    this.category,
    this.regID,
    this.error,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      message: json['message'] ?? '',
      category: json['category'],
      regID: json['regID'],
      error: json['error'],
    );
  }

  bool get isSuccess => error == null;
}


