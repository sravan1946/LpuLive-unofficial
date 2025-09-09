class CreateGroupResult {
  final String statusCode;
  final String message;
  final String? name;
  final dynamic data;

  CreateGroupResult({
    required this.statusCode,
    required this.message,
    this.name,
    this.data,
  });

  factory CreateGroupResult.fromJson(Map<String, dynamic> json) {
    return CreateGroupResult(
      statusCode: json['statusCode'] ?? '',
      message: json['message'] ?? '',
      name: json['name'],
      data: json['data'],
    );
  }

  bool get isSuccess => statusCode == '200';
}
