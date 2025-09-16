/// Result payload returned after attempting to create a group.
class CreateGroupResult {
  /// HTTP-like status code as string from backend.
  final String statusCode;

  /// Status message from backend.
  final String message;

  /// Optional created group name.
  final String? name;

  /// Optional backend-specific data payload.
  final dynamic data;

  /// Creates a [CreateGroupResult].
  CreateGroupResult({
    required this.statusCode,
    required this.message,
    this.name,
    this.data,
  });

  /// Parses a [CreateGroupResult] from JSON.
  factory CreateGroupResult.fromJson(Map<String, dynamic> json) {
    return CreateGroupResult(
      statusCode: json['statusCode'] ?? '',
      message: json['message'] ?? '',
      name: json['name'],
      data: json['data'],
    );
  }

  /// Convenience flag for a successful creation outcome.
  bool get isSuccess => statusCode == '200';
}
