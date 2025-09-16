/// Response model for user search queries.
class SearchResult {
  /// Status or result message.
  final String message;

  /// Optional category associated with the result.
  final String? category;

  /// Optional registration identifier.
  final String? regID;

  /// Optional error; null indicates success.
  final String? error;

  /// Creates a [SearchResult].
  SearchResult({required this.message, this.category, this.regID, this.error});

  /// Parses a [SearchResult] from JSON.
  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      message: json['message'] ?? '',
      category: json['category'],
      regID: json['regID'],
      error: json['error'],
    );
  }

  /// True when no error is present.
  bool get isSuccess => error == null;
}
