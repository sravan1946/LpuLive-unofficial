import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
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

  // Save current user data back to token storage
  static Future<void> saveCurrentUser() async {
    if (currentUser == null) return;

    try {
      // Convert user data back to JSON
      final userJson = currentUser!.toJson();

      // Convert to base64 encoded string
      final jsonString = jsonEncode(userJson);
      final base64Token = base64Encode(utf8.encode(jsonString));

      // Save to storage
      await saveToken(base64Token);
      debugPrint('✅ [TokenStorage] User data saved to storage');
    } catch (e) {
      debugPrint('❌ [TokenStorage] Failed to save user data: $e');
    }
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

        // Read raw bytes to preserve binary data
        final bytes = await consolidateHttpClientResponseBytes(response);

        // Collect headers
        final headers = <String, String>{};
        response.headers.forEach((key, values) {
          headers[key] = values.join(', ');
        });

        final httpResponse = http.Response.bytes(
          bytes,
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
      final url = '$_baseUrl/api/chats?course=$encodedCourse&page=1&chat_token=$chatToken';      debugPrint('🌐 [ChatApiService] Making HTTP request to: $url');
      final response = await http.get(Uri.parse(url));
      debugPrint('📥 [ChatApiService] Response Status: ${response.statusCode}');
      debugPrint('📥 [ChatApiService] Response Headers: ${response.headers}');
      debugPrint('📥 [ChatApiService] Response Body: ${response.body}');

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

  Future<List<Contact>> fetchContacts(String chatToken) async {
    try {
      final url = '$_baseUrl/api/groups/contacts';
      debugPrint('🌐 [ChatApiService] Making HTTP request to: $url');
      debugPrint('📤 [ChatApiService] Headers: {"Content-Type": "application/json"}');
      debugPrint('📤 [ChatApiService] Body: ${jsonEncode({'ChatToken': chatToken})}');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ChatToken': chatToken}),
      );

      debugPrint('📥 [ChatApiService] Response Status: ${response.statusCode}');
      debugPrint('📥 [ChatApiService] Response Headers: ${response.headers}');
      debugPrint('📥 [ChatApiService] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data.containsKey('contacts') && data['contacts'] is List) {
          final List<dynamic> contacts = data['contacts'];
          final contactList = contacts.map((json) => Contact.fromJson(json)).toList();
          debugPrint('✅ [ChatApiService] Successfully parsed ${contactList.length} contacts');
          return contactList;
        } else {
          debugPrint('⚠️ [ChatApiService] No contacts found in response');
          return [];
        }
      } else {
        // Try to extract error message from response body
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          if (errorData.containsKey('error')) {
            debugPrint('❌ [ChatApiService] API Error: ${errorData['error']}');
            throw Exception('${errorData['error']} (${response.statusCode})');
          } else {
            // No error field in response, throw generic error
            throw Exception('Failed to fetch contacts: ${response.statusCode}');
          }
        } on FormatException catch (parseError) {
          // Only catch JSON parsing errors, not our API error exceptions
          debugPrint('❌ [ChatApiService] Failed to parse error response: $parseError');
          throw Exception('Failed to fetch contacts: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('❌ [ChatApiService] Exception in fetchContacts: $e');
      debugPrint('❌ [ChatApiService] Exception type check: contains 404 = ${e.toString().contains('404')}');
      // If it's already an API error (contains status code), don't wrap it
      if (e.toString().contains('400') || e.toString().contains('401') || e.toString().contains('403') || e.toString().contains('404')) {
        debugPrint('❌ [ChatApiService] Re-throwing API error: $e');
        rethrow; // Re-throw the original API error
      }
      debugPrint('❌ [ChatApiService] Wrapping error: $e');
      throw Exception('Error fetching contacts: $e');
    }
  }

  Future<SearchResult> searchUser(String chatToken, String regID) async {
    try {
      final url = '$_baseUrl/api/groups/searchuser';
      debugPrint('🌐 [ChatApiService] Making HTTP request to: $url');
      debugPrint('📤 [ChatApiService] Headers: {"Content-Type": "application/json"}');
      debugPrint('📤 [ChatApiService] Body: ${jsonEncode({'ChatToken': chatToken, 'regID': regID})}');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ChatToken': chatToken, 'regID': regID}),
      );

      debugPrint('📥 [ChatApiService] Response Status: ${response.statusCode}');
      debugPrint('📥 [ChatApiService] Response Headers: ${response.headers}');
      debugPrint('📥 [ChatApiService] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final result = SearchResult.fromJson(data);
        debugPrint('✅ [ChatApiService] Search result: ${result.isSuccess ? 'Success' : 'Failed'} - ${result.message}');
        return result;
      } else {
        // Try to extract error message from response body
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          if (errorData.containsKey('error')) {
            debugPrint('❌ [ChatApiService] API Error: ${errorData['error']}');
            throw Exception(errorData['error']);
          }
        } catch (parseError) {
          // If we can't parse the error, fall back to status code
          debugPrint('❌ [ChatApiService] HTTP Error: ${response.statusCode}');
        }
        throw Exception('Failed to search user: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [ChatApiService] Exception in searchUser: $e');
      // If it's already an API error (contains status code), don't wrap it
      if (e.toString().contains('400') || e.toString().contains('401') || e.toString().contains('403') || e.toString().contains('404')) {
        rethrow; // Re-throw the original API error
      }
      throw Exception('Error searching user: $e');
    }
  }

  Future<CreateGroupResult> createGroup(String chatToken, String groupName, String members) async {
    try {
      final url = '$_baseUrl/api/groups/create';
      final requestBody = {
        'ChatToken': chatToken,
        'GroupName': groupName,
        'is_two_way': '',
        'Members': members,
        'one_To_One': true,
      };
      
      debugPrint('🌐 [ChatApiService] Making HTTP request to: $url');
      debugPrint('📤 [ChatApiService] Headers: {"Content-Type": "application/json"}');
      debugPrint('📤 [ChatApiService] Body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      debugPrint('📥 [ChatApiService] Response Status: ${response.statusCode}');
      debugPrint('📥 [ChatApiService] Response Headers: ${response.headers}');
      debugPrint('📥 [ChatApiService] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final result = CreateGroupResult.fromJson(data);
        debugPrint('✅ [ChatApiService] Group creation result: ${result.isSuccess ? 'Success' : 'Failed'} - ${result.message}');
        return result;
      } else {
        // Try to extract error message from response body
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          if (errorData.containsKey('error')) {
            debugPrint('❌ [ChatApiService] API Error: ${errorData['error']}');
            throw Exception('${errorData['error']} (${response.statusCode})');
          } else {
            // No error field in response, throw generic error
            throw Exception('Failed to create group: ${response.statusCode}');
          }
        } on FormatException catch (parseError) {
          // Only catch JSON parsing errors, not our API error exceptions
          debugPrint('❌ [ChatApiService] Failed to parse error response: $parseError');
          throw Exception('Failed to create group: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('❌ [ChatApiService] Exception in createGroup: $e');
      // If it's already an API error (contains status code), don't wrap it
      if (e.toString().contains('400') || e.toString().contains('401') || e.toString().contains('403') || e.toString().contains('404')) {
        rethrow; // Re-throw the original API error
      }
      throw Exception('Error creating group: $e');
    }
  }
}

// WebSocket Service for sending messages
class WebSocketChatService {
  static const String _wsBaseUrl = 'wss://lpulive.lpu.in';
  WebSocketChannel? _channel;
  final Uuid _uuid = Uuid();
  final StreamController<ChatMessage> _messageController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _systemMessageController = StreamController.broadcast();

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get systemMessageStream => _systemMessageController.stream;

  Future<void> connect(String chatToken) async {
    try {
      final wsUrl = '$_wsBaseUrl/ws/chat/?chat_token=$chatToken';
      debugPrint('🔌 [WebSocket] Connecting to: $wsUrl');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

       _channel!.stream.listen(
         (message) {
           try {
             final Map<String, dynamic> data = jsonDecode(message);
             debugPrint('📡 [WebSocket] Message received (${message.toString().length} chars)');

             // Check if this is a system message (force_disconnect, etc.)
             if (data.containsKey('type')) {
               debugPrint('📡 [WebSocket] System message received: ${data['type']}');
               _systemMessageController.add(data);

               // Handle force_disconnect
               if (data['type'] == 'force_disconnect') {
                 debugPrint('🚪 [WebSocket] Force disconnect received: ${data['message']}');
                 // The UI will handle the logout
               }
             }
             // Handle regular chat messages
             else if (data.containsKey('message_id') && data.containsKey('message')) {
               final chatMessage = ChatMessage.fromJson(data);
               _messageController.add(chatMessage);
             }
           } catch (e) {
             debugPrint('❌ [WebSocket] Error parsing message: $e');
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
      debugPrint('📤 [WebSocket] Sending message: ${jsonEncode(messageData)}');
      _channel!.sink.add(jsonEncode(messageData));
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  void disconnect() {
    _channel?.sink.close(status.goingAway);
    _channel = null;
    _messageController.close();
    _systemMessageController.close();
  }

  bool get isConnected => _channel != null;
}