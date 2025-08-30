import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/user_models.dart';

// Token Storage Service
class TokenStorage {
  static const String _tokenKey = 'auth_token';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    return token;
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}

// Custom HTTP client for handling SSL certificate issues
class CustomHttpClient {
  static Future<http.Response?> getWithCertificateHandling(String url) async {
    try {
      // First try with normal HTTP client
      final response = await http.get(Uri.parse(url));
      return response;
    } catch (e) {
      try {
        // Create HTTP client that ignores SSL certificate errors
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;

        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();

        // Convert HttpClientResponse to http.Response
        final responseBody = await response.transform(utf8.decoder).join();
        final headers = <String, String>{};
        response.headers.forEach((key, values) {
          headers[key] = values.join(', ');
        });

        final httpResponse = http.Response(
          responseBody,
          response.statusCode,
          headers: headers,
        );

        client.close();
        return httpResponse;
      } catch (e) {
        return null;
      }
    }
  }
}

// API Service for chat functionality
class ChatApiService {
  static const String _baseUrl = 'https://lpulive.lpu.in';

  Future<List<ChatMessage>> fetchChatMessages(String courseName, String chatToken) async {
    try {
      final encodedCourse = Uri.encodeComponent(courseName);
      final url = '$_baseUrl/api/chats?course=$encodedCourse&page=1&chat_token=$chatToken';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data.containsKey('chats') && data['chats'] is List) {
          final List<dynamic> chats = data['chats'];
          final messages = chats.map((json) => ChatMessage.fromJson(json)).toList();

          messages.sort((a, b) {
            try {
              final dateA = DateTime.parse(a.timestamp);
              final dateB = DateTime.parse(b.timestamp);
              return dateA.compareTo(dateB);
            } catch (e) {
              return 0;
            }
          });

          return messages;
        } else {
          return [];
        }
      } else {
        throw Exception('Failed to fetch chat messages: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching chat messages: $e');
    }
  }
}

// WebSocket Service for sending messages
class WebSocketChatService {
  static const String _wsBaseUrl = 'wss://lpulive.lpu.in';
  WebSocketChannel? _channel;
  final Uuid _uuid = Uuid();
  final StreamController<ChatMessage> _messageController = StreamController.broadcast();

  Stream<ChatMessage> get messageStream => _messageController.stream;

  Future<void> connect(String chatToken) async {
    try {
      final wsUrl = '$_wsBaseUrl/ws/chat/?chat_token=$chatToken';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        (message) {
          try {
            final Map<String, dynamic> data = jsonDecode(message);

            if (data.containsKey('message_id') && data.containsKey('message')) {
              final chatMessage = ChatMessage.fromJson(data);
              _messageController.add(chatMessage);
            }
          } catch (e) {
            // Ignore parsing errors
          }
        },
        onError: (error) {
          // Handle error
        },
        onDone: () {
          // Handle connection closed
        },
      );
    } catch (e) {
      throw Exception('Failed to connect to WebSocket: $e');
    }
  }

  Future<void> sendMessage({
    required String message,
    required String group,
  }) async {
    if (_channel == null) {
      throw Exception('WebSocket not connected');
    }

    final cleanGroup = group.replaceFirst(RegExp(r'^DM:\s*'), '');
    final tempId = _uuid.v4().replaceAll('-', '').substring(0, 32);

    final messageData = {
      'message': message,
      'group': cleanGroup,
      'temp_id': tempId,
      'action': 'send',
    };

    try {
      _channel!.sink.add(jsonEncode(messageData));
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  void disconnect() {
    _channel?.sink.close(status.goingAway);
    _channel = null;
    _messageController.close();
  }

  bool get isConnected => _channel != null;
}