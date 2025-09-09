class ApiConfig {
  // LPU Live API Configuration
  static const String baseUrl = 'https://lpulive.lpu.in';

  // Authentication endpoints
  static const String login = '/api/auth';

  // Other endpoints (add as needed)
  static const String chat = '/api/chat';
  static const String groups = '/api/groups';

  // Timeout configurations
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // API headers
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
