// Dart imports:
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:mime/mime.dart' as mime;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

// Project imports:
import '../models/group_user_model.dart';
import '../models/user_models.dart';
import '../utils/sender_name_utils.dart';
import 'avatar_cache_service.dart';
import 'background_websocket_service.dart';
import 'connectivity_service.dart';

// Custom exception for unauthorized access
class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);

  @override
  String toString() => 'UnauthorizedException: $message';
}

// Custom exception for network connectivity issues
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

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

  /// Authenticate a user using username, password and Cloudflare Turnstile token
  Future<User> authenticateWithCredentials({
    required String username,
    required String password,
    required String turnstileToken,
  }) async {
    try {
      // Check internet connectivity first
      final connectivityService = ConnectivityService();
      final hasInternet = await connectivityService.hasInternetConnection();
      if (!hasInternet) {
        throw NetworkException(
          'No internet connection. Please check your network and try again.',
        );
      }

      final url = '$_baseUrl/api/auth';
      final requestBody = {
        'user': username,
        'password': password,
        'cf-turnstile-response': turnstileToken,
      };

      debugPrint('🌐 [ChatApiService] Authenticating with credentials at: $url');
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      debugPrint('📥 [ChatApiService] Auth Response: ${response.statusCode}');
      debugPrint('📥 [ChatApiService] Auth Response Body: ${response.body}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final user = User.fromJson(data);
        return user;
      }

      // Map common HTTP errors to UI-recognized messages
      // so that the login screen can display specific guidance
      String normalizedError = '';
      try {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        normalizedError = (errorData['error'] ?? '').toString();
      } catch (_) {
        // ignore parse errors; we'll fall back to status code mapping
      }

      // Prefer explicit status codes observed from backend
      // 410 -> Invalid User, 400 -> Invalid CAPTCHA, 413 -> Invalid Password
      if (response.statusCode == 410) {
        throw Exception('Invalid User');
      }
      if (response.statusCode == 400) {
        throw Exception('Invalid CAPTCHA');
      }
      if (response.statusCode == 413) {
        throw Exception('Invalid Password');
      }

      // Heuristics based on response body (fallback)
      final bodyLower = normalizedError.toLowerCase();
      if (bodyLower.contains('captcha')) {
        throw Exception('Invalid CAPTCHA');
      }
      if (bodyLower.contains('password')) {
        throw Exception('Invalid Password');
      }
      if (bodyLower.contains('user')) {
        throw Exception('Invalid User');
      }

      // Fallback
      throw Exception('Authentication failed: ${response.statusCode}');
    } catch (e) {
      if (e is NetworkException) rethrow;
      throw Exception('Error during authentication: $e');
    }
  }

  /// Authorize user with existing chat token
  /// Returns updated User object with new token if successful
  /// Throws exception if token is invalid (401 Unauthorized)
  Future<User> authorizeUser(String chatToken) async {
    try {
      // Check internet connectivity first
      final connectivityService = ConnectivityService();
      final hasInternet = await connectivityService.hasInternetConnection();
      if (!hasInternet) {
        debugPrint('🌐 [ChatApiService] No internet connection detected');
        throw NetworkException(
          'No internet connection. Please check your network and try again.',
        );
      }

      final url = '$_baseUrl/api/authorize';
      final requestBody = {'ChatToken': chatToken};

      debugPrint('🌐 [ChatApiService] Making authorize request to: $url');
      debugPrint('📤 [ChatApiService] Body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      debugPrint(
        '📥 [ChatApiService] Authorize Response Status: ${response.statusCode}',
      );
      debugPrint(
        '📥 [ChatApiService] Authorize Response Body: ${response.body}',
      );

      if (response.statusCode == 200) {
        debugPrint('🔍 [ChatApiService] Parsing authorize response...');
        final Map<String, dynamic> data = jsonDecode(response.body);
        debugPrint(
          '🔍 [ChatApiService] JSON parsed successfully, creating User...',
        );
        final user = User.fromJson(data);
        debugPrint('✅ [ChatApiService] User authorized successfully');
        return user;
      } else if (response.statusCode == 401) {
        // Handle unauthorized response
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          final errorMessage =
              errorData['error'] ?? 'Unauthorized access. Please login again.';
          debugPrint('❌ [ChatApiService] Authorization failed: $errorMessage');
          throw UnauthorizedException(errorMessage);
        } catch (parseError) {
          debugPrint(
            '❌ [ChatApiService] Authorization failed: 401 Unauthorized',
          );
          throw UnauthorizedException(
            'Unauthorized access. Please login again.',
          );
        }
      } else {
        debugPrint(
          '❌ [ChatApiService] Authorization failed: ${response.statusCode}',
        );
        throw Exception('Authorization failed: ${response.statusCode}');
      }
    } catch (e) {
      if (e is UnauthorizedException) {
        rethrow;
      }

      // Handle network connectivity issues
      if (e.toString().contains('SocketException') ||
          e.toString().contains('ClientException') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('No address associated with hostname')) {
        debugPrint(
          '🌐 [ChatApiService] Network error during authorization: $e',
        );
        throw NetworkException(
          'No internet connection. Please check your network and try again.',
        );
      }

      debugPrint('❌ [ChatApiService] Exception in authorizeUser: $e');
      throw Exception('Error during authorization: $e');
    }
  }

  Future<List<ChatMessage>> fetchChatMessages(
    String courseName,
    String chatToken, {
    int page = 1,
  }) async {
    try {
      final encodedCourse = Uri.encodeComponent(courseName);
      final url =
          '$_baseUrl/api/chats?course=$encodedCourse&page=$page&chat_token=$chatToken';
      debugPrint('🌐 [ChatApiService] Making HTTP request to: $url');
      final response = await http.get(Uri.parse(url));
      debugPrint('📥 [ChatApiService] Response Status: ${response.statusCode}');
      debugPrint('📥 [ChatApiService] Response Headers: ${response.headers}');
      debugPrint('📥 [ChatApiService] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data.containsKey('chats') && data['chats'] is List) {
          final List<dynamic> chats = data['chats'];
          final messages = chats
              .map((json) => ChatMessage.fromJson(json))
              .toList();

          messages.sort((a, b) {
            try {
              final dateA = DateTime.parse(a.timestamp);
              final dateB = DateTime.parse(b.timestamp);
              return dateA.compareTo(dateB);
            } catch (e) {
              return 0;
            }
          });

          // Cache userImage from chat messages
          for (final message in messages) {
            if (message.userImage != null && message.userImage!.isNotEmpty) {
              await AvatarCacheService.cacheAvatar(
                message.sender,
                message.userImage,
              );
              debugPrint(
                '💾 [ChatApiService] Cached userImage for ${message.sender}: ${message.userImage}',
              );
            }
          }

          return messages;
        } else {
          return [];
        }
      } else if (response.statusCode == 401) {
        // Handle unauthorized response - token is invalid
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          final errorMessage =
              errorData['error'] ?? 'Unauthorized access. Please login again.';
          debugPrint(
            '❌ [ChatApiService] Authorization failed (401): $errorMessage',
          );
          throw UnauthorizedException(errorMessage);
        } catch (parseError) {
          if (parseError is UnauthorizedException) {
            rethrow;
          }
          debugPrint(
            '❌ [ChatApiService] Authorization failed: 401 Unauthorized',
          );
          throw UnauthorizedException(
            'Unauthorized access. Please login again.',
          );
        }
      } else {
        throw Exception(
          'Failed to fetch chat messages: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is UnauthorizedException) {
        rethrow;
      }
      throw Exception('Error fetching chat messages: $e');
    }
  }

  Future<List<Contact>> fetchContacts(String chatToken) async {
    try {
      final url = '$_baseUrl/api/groups/contacts';
      debugPrint('🌐 [ChatApiService] Making HTTP request to: $url');
      debugPrint(
        '📤 [ChatApiService] Headers: {"Content-Type": "application/json"}',
      );
      debugPrint(
        '📤 [ChatApiService] Body: ${jsonEncode({'ChatToken': chatToken})}',
      );

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
          final contactList = contacts
              .map((json) => Contact.fromJson(json))
              .toList();
          debugPrint(
            '✅ [ChatApiService] Successfully parsed ${contactList.length} contacts',
          );
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
          debugPrint(
            '❌ [ChatApiService] Failed to parse error response: $parseError',
          );
          throw Exception('Failed to fetch contacts: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('❌ [ChatApiService] Exception in fetchContacts: $e');
      debugPrint(
        '❌ [ChatApiService] Exception type check: contains 404 = ${e.toString().contains('404')}',
      );
      // If it's already an API error (contains status code), don't wrap it
      if (e.toString().contains('400') ||
          e.toString().contains('401') ||
          e.toString().contains('403') ||
          e.toString().contains('404')) {
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
      debugPrint(
        '📤 [ChatApiService] Headers: {"Content-Type": "application/json"}',
      );
      debugPrint(
        '📤 [ChatApiService] Body: ${jsonEncode({'ChatToken': chatToken, 'regID': regID})}',
      );

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
        debugPrint(
          '✅ [ChatApiService] Search result: ${result.isSuccess ? 'Success' : 'Failed'} - ${result.message}',
        );
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
      if (e.toString().contains('400') ||
          e.toString().contains('401') ||
          e.toString().contains('403') ||
          e.toString().contains('404')) {
        rethrow; // Re-throw the original API error
      }
      throw Exception('Error searching user: $e');
    }
  }

  Future<CreateGroupResult> createGroup(
    String chatToken,
    String groupName,
    String members,
  ) async {
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
      debugPrint(
        '📤 [ChatApiService] Headers: {"Content-Type": "application/json"}',
      );
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
        debugPrint(
          '✅ [ChatApiService] Group creation result: ${result.isSuccess ? 'Success' : 'Failed'} - ${result.message}',
        );

        // If the group creation was successful, refresh user data with authorize endpoint
        if (result.isSuccess) {
          try {
            debugPrint(
              '🔄 [ChatApiService] Refreshing user data after successful group creation...',
            );
            final updatedUser = await authorizeUser(chatToken);
            setCurrentUser(updatedUser);
            await TokenStorage.saveCurrentUser();
            debugPrint('✅ [ChatApiService] User data refreshed successfully');
          } catch (e) {
            if (e is NetworkException) {
              debugPrint(
                '🌐 [ChatApiService] Network error during user refresh after group creation: $e',
              );
              // Don't fail the group creation for network errors, just log the warning
            } else {
              debugPrint(
                '⚠️ [ChatApiService] Failed to refresh user data after group creation: $e',
              );
            }
            // Don't fail the group creation if refresh fails, just log the warning
          }
        }

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
          debugPrint(
            '❌ [ChatApiService] Failed to parse error response: $parseError',
          );
          throw Exception('Failed to create group: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('❌ [ChatApiService] Exception in createGroup: $e');
      // If it's already an API error (contains status code), don't wrap it
      if (e.toString().contains('400') ||
          e.toString().contains('401') ||
          e.toString().contains('403') ||
          e.toString().contains('404')) {
        rethrow; // Re-throw the original API error
      }
      throw Exception('Error creating group: $e');
    }
  }

  Future<CreateGroupResult> performGroupAction(
    String chatToken,
    String action,
    String groupName,
  ) async {
    try {
      final url = '$_baseUrl/api/groups/actions';
      final requestBody = {
        'ChatToken': chatToken,
        'Action': action,
        'Group': groupName,
      };

      debugPrint('🌐 [ChatApiService] Making HTTP request to: $url');
      debugPrint(
        '📤 [ChatApiService] Headers: {"Content-Type": "application/json"}',
      );
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

        // Handle the specific response format for group actions
        CreateGroupResult result;
        if (data.containsKey('statusCode') && data.containsKey('message')) {
          result = CreateGroupResult(
            statusCode: data['statusCode'] ?? '',
            message: data['message'] ?? '',
            name: '',
            data: data,
          );
        } else {
          // Fallback to original parsing for other response formats
          result = CreateGroupResult.fromJson(data);
        }

        debugPrint(
          '✅ [ChatApiService] Group action result: ${result.isSuccess ? 'Success' : 'Failed'} - ${result.message}',
        );

        // If the group action was successful, refresh user data with authorize endpoint
        if (result.isSuccess) {
          try {
            debugPrint(
              '🔄 [ChatApiService] Refreshing user data after successful group action...',
            );
            final updatedUser = await authorizeUser(chatToken);
            setCurrentUser(updatedUser);
            await TokenStorage.saveCurrentUser();
            debugPrint('✅ [ChatApiService] User data refreshed successfully');
          } catch (e) {
            if (e is NetworkException) {
              debugPrint(
                '🌐 [ChatApiService] Network error during user refresh after group action: $e',
              );
              // Don't fail the group action for network errors, just log the warning
            } else {
              debugPrint(
                '⚠️ [ChatApiService] Failed to refresh user data after group action: $e',
              );
            }
            // Don't fail the group action if refresh fails, just log the warning
          }
        }

        return result;
      } else {
        // Try to extract error message from response body
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          if (errorData.containsKey('error')) {
            debugPrint('❌ [ChatApiService] API Error: ${errorData['error']}');
            // Return a CreateGroupResult with error info instead of throwing
            return CreateGroupResult(
              statusCode: response.statusCode.toString(),
              message: errorData['error'],
              name: '',
              data: errorData,
            );
          }
        } on FormatException catch (parseError) {
          // Only catch JSON parsing errors, not our API error exceptions
          debugPrint(
            '❌ [ChatApiService] Failed to parse error response: $parseError',
          );
          return CreateGroupResult(
            statusCode: response.statusCode.toString(),
            message: 'Failed to perform group action: ${response.statusCode}',
            name: '',
            data: null,
          );
        }
        // No error field in response, return generic error
        return CreateGroupResult(
          statusCode: response.statusCode.toString(),
          message: 'Failed to perform group action: ${response.statusCode}',
          name: '',
          data: null,
        );
      }
    } catch (e) {
      debugPrint('❌ [ChatApiService] Exception in performGroupAction: $e');
      // If it's already an API error (contains status code), don't wrap it
      if (e.toString().contains('400') ||
          e.toString().contains('401') ||
          e.toString().contains('403') ||
          e.toString().contains('404')) {
        rethrow; // Re-throw the original API error
      }
      throw Exception('Error performing group action: $e');
    }
  }

  Future<CreateGroupResult> performCriticalGroupAction(
    String chatToken,
    String action,
    String groupName,
  ) async {
    try {
      final url = '$_baseUrl/api/groups/actions_critical';
      final requestBody = {
        'ChatToken': chatToken,
        'Action': action,
        'Group': groupName,
      };

      debugPrint('🌐 [ChatApiService] Making HTTP request to: $url');
      debugPrint(
        '📤 [ChatApiService] Headers: {"Content-Type": "application/json"}',
      );
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

        // Handle flexible response format
        CreateGroupResult result;
        if (data.containsKey('statusCode') && data.containsKey('message')) {
          result = CreateGroupResult(
            statusCode: data['statusCode'] ?? '',
            message: data['message'] ?? '',
            name: '',
            data: data,
          );
        } else {
          result = CreateGroupResult.fromJson(data);
        }

        debugPrint(
          '✅ [ChatApiService] Critical action result: ${result.isSuccess ? 'Success' : 'Failed'} - ${result.message}',
        );

        if (result.isSuccess) {
          try {
            debugPrint(
              '🔄 [ChatApiService] Refreshing user data after critical action...',
            );
            final updatedUser = await authorizeUser(chatToken);
            setCurrentUser(updatedUser);
            await TokenStorage.saveCurrentUser();
            debugPrint('✅ [ChatApiService] User data refreshed successfully');
          } catch (e) {
            if (e is NetworkException) {
              debugPrint(
                '🌐 [ChatApiService] Network error during user refresh after critical action: $e',
              );
            } else {
              debugPrint(
                '⚠️ [ChatApiService] Failed to refresh user data after critical action: $e',
              );
            }
          }
        }

        return result;
      } else {
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          if (errorData.containsKey('error')) {
            debugPrint('❌ [ChatApiService] API Error: ${errorData['error']}');
            return CreateGroupResult(
              statusCode: response.statusCode.toString(),
              message: errorData['error'],
              name: '',
              data: errorData,
            );
          }
        } on FormatException catch (parseError) {
          debugPrint(
            '❌ [ChatApiService] Failed to parse error response: $parseError',
          );
          return CreateGroupResult(
            statusCode: response.statusCode.toString(),
            message:
                'Failed to perform critical action: ${response.statusCode}',
            name: '',
            data: null,
          );
        }

        return CreateGroupResult(
          statusCode: response.statusCode.toString(),
          message: 'Failed to perform critical action: ${response.statusCode}',
          name: '',
          data: null,
        );
      }
    } catch (e) {
      debugPrint(
        '❌ [ChatApiService] Exception in performCriticalGroupAction: $e',
      );
      if (e.toString().contains('400') ||
          e.toString().contains('401') ||
          e.toString().contains('403') ||
          e.toString().contains('404')) {
        rethrow;
      }
      throw Exception('Error performing critical group action: $e');
    }
  }

  Future<GroupDetails> fetchGroupUsers(
    String chatToken,
    String groupName,
  ) async {
    try {
      final url = '$_baseUrl/api/groups/group-users';
      final requestBody = {'chat_token': chatToken, 'group_name': groupName};

      debugPrint('🌐 [ChatApiService] Making HTTP request to: $url');
      debugPrint(
        '📤 [ChatApiService] Headers: {"Content-Type": "application/json"}',
      );
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
        final groupDetails = GroupDetails.fromJson(data);
        debugPrint(
          '✅ [ChatApiService] Successfully fetched group details with ${groupDetails.users.length} users',
        );
        return groupDetails;
      } else {
        // Try to extract error message from response body
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          if (errorData.containsKey('error')) {
            debugPrint('❌ [ChatApiService] API Error: ${errorData['error']}');
            throw Exception('${errorData['error']} (${response.statusCode})');
          } else {
            // No error field in response, throw generic error
            throw Exception(
              'Failed to fetch group users: ${response.statusCode}',
            );
          }
        } on FormatException catch (parseError) {
          // Only catch JSON parsing errors, not our API error exceptions
          debugPrint(
            '❌ [ChatApiService] Failed to parse error response: $parseError',
          );
          throw Exception(
            'Failed to fetch group users: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ [ChatApiService] Exception in fetchGroupUsers: $e');
      // If it's already an API error (contains status code), don't wrap it
      if (e.toString().contains('400') ||
          e.toString().contains('401') ||
          e.toString().contains('403') ||
          e.toString().contains('404')) {
        rethrow; // Re-throw the original API error
      }
      throw Exception('Error fetching group users: $e');
    }
  }

  Future<List<GroupMediaItem>> fetchGroupMedia(
    String chatToken,
    String groupName,
  ) async {
    try {
      final url = '$_baseUrl/api/groups/media';
      final requestBody = {
        'ChatToken': chatToken,
        'group_name': groupName,
      };

      debugPrint('🌐 [ChatApiService] Making HTTP request to: $url');
      debugPrint(
        '📤 [ChatApiService] Headers: {"Content-Type": "application/json"}',
      );
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
        if (data.containsKey('media') && data['media'] is List) {
          final List<dynamic> media = data['media'];
          final mediaList = media
              .map((json) => GroupMediaItem.fromJson(json))
              .toList();
          debugPrint(
            '✅ [ChatApiService] Successfully parsed ${mediaList.length} media items',
          );
          return mediaList;
        } else {
          debugPrint('⚠️ [ChatApiService] No media found in response');
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
            throw Exception('Failed to fetch group media: ${response.statusCode}');
          }
        } on FormatException catch (parseError) {
          debugPrint(
            '❌ [ChatApiService] Failed to parse error response: $parseError',
          );
          throw Exception('Failed to fetch group media: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('❌ [ChatApiService] Exception in fetchGroupMedia: $e');
      if (e.toString().contains('400') ||
          e.toString().contains('401') ||
          e.toString().contains('403') ||
          e.toString().contains('404')) {
        rethrow; // Re-throw the original API error
      }
      throw Exception('Error fetching group media: $e');
    }
  }

  /// Upload a file to a group.
  /// Sends a multipart/form-data POST to /backend/upload/ with fields:
  /// - chat_token
  /// - group_name
  /// - message
  /// - file (binary)
  Future<void> uploadGroupFile({
    required String chatToken,
    required String groupName,
    required String message,
    required String filePath,
    String? filename,
  }) async {
    final uri = Uri.parse('$_baseUrl/backend/upload/');
    try {
      final request = http.MultipartRequest('POST', uri);
      request.fields['chat_token'] = chatToken;
      request.fields['group_name'] = groupName;
      request.fields['message'] = message;

      // Detect MIME type from file extension
      final contentTypeString = mime.lookupMimeType(filePath);
      http.MultipartFile multipartFile;
      if (contentTypeString != null && contentTypeString.contains('/')) {
        final parts = contentTypeString.split('/');
        final mediaType = MediaType(parts[0], parts.length > 1 ? parts[1] : 'octet-stream');
        multipartFile = await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: filename,
          contentType: mediaType,
        );
      } else {
        multipartFile = await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: filename,
        );
      }
      request.files.add(multipartFile);

      // Debug: log outgoing fields (without binary)
      debugPrint('📤 [Upload] POST $uri');
      debugPrint('📤 [Upload] Fields: chat_token=${chatToken.isNotEmpty}, group_name="$groupName", message="${request.fields['message']}"');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('Upload failed: ${response.statusCode}');
      }

      // Try to parse JSON and check status
      try {
        final Map<String, dynamic> data = jsonDecode(response.body);
        debugPrint('📥 [Upload] Response: ${response.body}');
        if ((data['status'] ?? '') != 'success') {
          throw Exception(data['message'] ?? 'Upload failed');
        }
      } catch (_) {
        // If not JSON or different format, assume success on 200
      }
    } catch (e) {
      throw Exception('Error uploading file: $e');
    }
  }
}

enum ConnectionStatus { connecting, connected, disconnected, reconnecting }

// WebSocket Service for sending messages
class WebSocketChatService {
  static const String _wsBaseUrl = 'wss://lpulive.lpu.in';
  WebSocketChannel? _channel;
  final Uuid _uuid = Uuid();
  final StreamController<ChatMessage> _messageController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _systemMessageController =
      StreamController.broadcast();
  final StreamController<ConnectionStatus> _connectionStatusController =
      StreamController.broadcast();

  // Reconnect/backoff state
  bool _explicitlyClosed = false;
  bool _shouldAttemptReconnect = true;
  String? _lastChatToken;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  final Random _random = Random();

  // Notification handling
  static const String _notificationChannelId = 'lpulive_messages';
  static const String _notificationChannelName = 'LPU Live Messages';
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Notification grouping - track messages per group/conversation
  static final Map<String, List<Map<String, dynamic>>> _groupedMessages = {};
  static final Map<String, int> _groupMessageCounts = {};

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get systemMessageStream =>
      _systemMessageController.stream;
  Stream<ConnectionStatus> get connectionStatusStream =>
      _connectionStatusController.stream;
  ConnectionStatus _currentStatus = ConnectionStatus.disconnected;
  ConnectionStatus get connectionStatus => _currentStatus;

  void _setStatus(ConnectionStatus status) {
    _currentStatus = status;
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add(status);
    }
  }

  Future<void> connect(String chatToken) async {
    try {
      _explicitlyClosed = false;
      _shouldAttemptReconnect = true;
      _lastChatToken = chatToken;
      _reconnectTimer?.cancel();
      _setStatus(ConnectionStatus.connecting);

      // Initialize notifications
      await _initializeNotifications();

      // Store token for background service
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chat_token', chatToken);

      // Start background service to keep process alive
      await BackgroundWebSocketService.startBackgroundService(chatToken);

      // Check connectivity before attempting connection
      try {
        final connectivity = await Connectivity().checkConnectivity().timeout(
          const Duration(seconds: 5),
          onTimeout: () => [ConnectivityResult.none],
        );

        final hasConnectivity = connectivity.any((result) => result != ConnectivityResult.none);
        if (!hasConnectivity) {
          debugPrint('📡 [WebSocket] No internet connection available: $connectivity');
          _handleSocketClosed('no connectivity');
          return;
        }

        debugPrint('📡 [WebSocket] Connectivity check passed: $connectivity');
      } catch (e) {
        debugPrint('❌ [WebSocket] Connectivity check failed: $e');
        _handleSocketClosed('connectivity check failed');
        return;
      }

      final wsUrl = '$_wsBaseUrl/ws/chat/?chat_token=$chatToken';
      debugPrint('🔌 [WebSocket] Connecting to: $wsUrl');

      // Wrap WebSocket connection in try-catch to prevent unhandled exceptions
      try {
        _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      } catch (e) {
        debugPrint('❌ [WebSocket] Failed to create WebSocket channel: $e');
        _handleSocketClosed('WebSocket channel creation failed');
        return;
      }

      _channel!.stream.listen(
        (message) async {
          try {
            final Map<String, dynamic> data = jsonDecode(message);
            debugPrint(
              '📡 [WebSocket] Message received (${message.toString().length} chars)',
            );

            // Check if this is a system message (force_disconnect, etc.)
            if (data.containsKey('type')) {
              debugPrint(
                '📡 [WebSocket] System message received: ${data['type']}',
              );
              _systemMessageController.add(data);

              // Handle force_disconnect
              if (data['type'] == 'force_disconnect') {
                debugPrint(
                  '🚪 [WebSocket] Force disconnect received: ${data['message']}',
                );
                // Stop reconnect attempts and close the socket
                _shouldAttemptReconnect = false;
                _explicitlyClosed = true;
                _reconnectTimer?.cancel();
                _channel?.sink.close(status.normalClosure);
                _setStatus(ConnectionStatus.disconnected);
                // The UI will handle the logout
              }
            }
            // Handle regular chat messages
            else if (data.containsKey('message_id') &&
                data.containsKey('message')) {
              final chatMessage = ChatMessage.fromJson(data);
              _messageController.add(chatMessage);

              // Show notification for new messages when app is in background
              if (data['is_own_message'] != true) {
                await _showMessageNotification(data);
              }

              if (_currentStatus != ConnectionStatus.connected) {
_setStatus(ConnectionStatus.connected);
                _reconnectAttempts = 0; // reset on successful traffic
              }
            }
          } catch (e) {
            debugPrint('❌ [WebSocket] Error parsing message: $e');
            // Ignore parsing errors
          }
        },
        onError: (error) {
          debugPrint('❌ [WebSocket] Stream error: $error');
          _handleSocketClosed('error: $error');
        },
        onDone: () {
          debugPrint('🔌 [WebSocket] Connection closed');
          _handleSocketClosed('done');
        },
      );
      // If we reach here without immediate close, mark as connected-on-open
      _setStatus(ConnectionStatus.connected);
    } catch (e) {
      debugPrint('❌ [WebSocket] Connect threw: $e');
      _handleSocketClosed('exception: $e');
      throw Exception('Failed to connect to WebSocket: $e');
    }
  }

  void _handleSocketClosed(String reason) {
    _channel = null;
    if (_explicitlyClosed || !_shouldAttemptReconnect) {
      debugPrint(
        '🔕 [WebSocket] Not reconnecting (explicitly closed or disabled).',
      );
      _setStatus(ConnectionStatus.disconnected);
      return;
    }

    _scheduleReconnect(reason);
  }

  void _scheduleReconnect(String reason) {
    _reconnectTimer?.cancel();

    // More conservative approach for network issues
    int delayMs;
    if (reason.contains('host lookup') || reason.contains('connectivity') || reason.contains('no connectivity')) {
      // Network issues - use longer delays
      delayMs = min(60000, 10000 * _reconnectAttempts); // 10s, 20s, 30s, 40s, 50s, 60s
    } else {
      // Other issues - standard backoff
      final baseDelayMs = 1000 * pow(2, min(_reconnectAttempts, 5)).toInt(); // cap at 32s
      final jitterMs = _random.nextInt(500);
      delayMs = min(30000, baseDelayMs) + jitterMs; // cap total at ~30.5s
    }

    _reconnectAttempts += 1;
    _setStatus(ConnectionStatus.reconnecting);
    debugPrint(
      '⏳ [WebSocket] Scheduling reconnect in ${delayMs}ms (attempt: $_reconnectAttempts). Reason: $reason',
    );
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (_explicitlyClosed || !_shouldAttemptReconnect) {
        debugPrint('🔕 [WebSocket] Reconnect cancelled before attempt.');
        return;
      }

      // Check connectivity before attempting reconnection
      try {
        final connectivity = await Connectivity().checkConnectivity().timeout(
          const Duration(seconds: 3),
          onTimeout: () => [ConnectivityResult.none],
        );

        final hasConnectivity = connectivity.any((result) => result != ConnectivityResult.none);
        if (!hasConnectivity) {
          debugPrint('📡 [WebSocket] Still no connectivity, will retry later');
          _scheduleReconnect('still no connectivity');
          return;
        }

        debugPrint('📡 [WebSocket] Connectivity restored, attempting reconnection...');
      } catch (e) {
        debugPrint('❌ [WebSocket] Connectivity check failed: $e');
        _scheduleReconnect('connectivity check failed');
        return;
      }

      final token = _lastChatToken;
      if (token == null) {
        debugPrint('⚠️ [WebSocket] No token available for reconnect.');
        _setStatus(ConnectionStatus.disconnected);
        return;
      }
      try {
        await connect(token);
      } catch (e) {
        // connect() already funnels into _handleSocketClosed; nothing else to do
      }
    });
  }

  Future<void> sendMessage({
    required String message,
    required String group,
    String? replyToMessageId,
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
      'action': replyToMessageId != null ? 'reply' : 'send',
      if (replyToMessageId != null) 'message_id': replyToMessageId,
      if (replyToMessageId != null) 'reply_type': 'p',
    };

    try {
      debugPrint('📤 [WebSocket] Sending message: ${jsonEncode(messageData)}');
      _channel!.sink.add(jsonEncode(messageData));
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  Future<void> deleteMessage({required String messageId}) async {
    if (_channel == null) {
      throw Exception('WebSocket not connected');
    }
    final payload = {'action': 'delete', 'message_id': messageId};
    try {
      debugPrint('🗑️ [WebSocket] Deleting message: ${jsonEncode(payload)}');
      _channel!.sink.add(jsonEncode(payload));
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  void disconnect() {
    _explicitlyClosed = true;
    _shouldAttemptReconnect = false;
    _reconnectTimer?.cancel();
    _channel?.sink.close(status.normalClosure);
    _channel = null;

    // Stop background service
    BackgroundWebSocketService.stopBackgroundService();

    // Keep controllers alive so listeners remain valid if a new instance is not created.
    // They will be closed when the service is disposed by GC/app shutdown.
    _setStatus(ConnectionStatus.disconnected);
  }

  bool get isConnected => _channel != null;

  void dispose() {
    _explicitlyClosed = true;
    _shouldAttemptReconnect = false;
    _reconnectTimer?.cancel();
    _channel?.sink.close(status.normalClosure);
    _channel = null;
    _messageController.close();
    _systemMessageController.close();
    _connectionStatusController.close();
  }

  /// Initialize local notifications
  static Future<void> _initializeNotifications() async {
    const androidChannel = AndroidNotificationChannel(
      _notificationChannelId,
      _notificationChannelName,
      description: 'Notifications for new messages',
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Show grouped notification for new message
  static Future<void> _showMessageNotification(Map<String, dynamic> messageData) async {
    try {
      // Don't show notification for own messages
      if (messageData['is_own_message'] == true) return;

      // Get group identifier (use group field or sender for direct messages)
      final groupId = messageData['group']?.toString() ??
                     messageData['sender']?.toString() ??
                     'unknown';

      // Initialize group if it doesn't exist
      if (!_groupedMessages.containsKey(groupId)) {
        _groupedMessages[groupId] = [];
        _groupMessageCounts[groupId] = 0;
      }

      // Add message to group
      _groupedMessages[groupId]!.add(messageData);
      _groupMessageCounts[groupId] = _groupMessageCounts[groupId]! + 1;

      // Keep only last 5 messages per group to avoid memory issues
      if (_groupedMessages[groupId]!.length > 5) {
        _groupedMessages[groupId]!.removeAt(0);
      }

      // Get the latest message for preview
      final latestMessage = _groupedMessages[groupId]!.last;
      final rawSenderName = latestMessage['UserName'] ?? '';
      final sender = SenderNameUtils.parseSenderName(rawSenderName);
      final message = latestMessage['message'] ?? '';

      // Create notification title and body based on group
      String title;
      String body;

      // Get sender name for the group (could be from first or latest message)
      final allSenders = _groupedMessages[groupId]!
          .map((msg) => SenderNameUtils.parseSenderName(msg['UserName'] ?? ''))
          .toSet()
          .toList();

      // Helper function to get a shortened group name
      String getShortGroupName(String? groupName) {
        if (groupName == null || groupName.isEmpty) return 'Direct Message';
        if (RegExp(r'^\d+\s*:\s*\d+$').hasMatch(groupName)) return 'Direct Message';
        // Remove course code prefix for university groups (e.g., "MECH101 - Dynamics" -> "Dynamics")
        final cleaned = groupName.replaceFirst(RegExp(r'^[A-Z]+\d+\s*-\s*'), '');
        // Truncate if too long
        if (cleaned.length > 30) {
          return '${cleaned.substring(0, 27)}...';
        }
        return cleaned;
      }

      final int messageCount = _groupMessageCounts[groupId]!;
      final bool isDirectMessage = groupId.startsWith('unknown') ||
          RegExp(r'^\d+\s*:\s*\d+$').hasMatch(groupId);

      String deriveBaseTitle() {
        if (isDirectMessage) {
          if (sender.isNotEmpty) return sender;
          return 'Direct Message';
        }
        return getShortGroupName(groupId);
      }

      final baseTitle = deriveBaseTitle();

      // Format all messages into a list
      String formatAllMessages() {
        final messages = _groupedMessages[groupId]!;
        final formattedMessages = <String>[];

        for (final msg in messages) {
          final msgText = (msg['message']?.toString() ?? '').trimRight();
          if (msgText.isEmpty) continue;

          if (allSenders.length == 1) {
            // Single sender - just show the message
            formattedMessages.add(msgText);
          } else {
            // Multiple senders - show sender name with message
            final msgSender = SenderNameUtils.parseSenderName(msg['UserName']?.toString() ?? '');
            final senderName = msgSender.isNotEmpty ? msgSender : 'Unknown';
            formattedMessages.add('$senderName: $msgText');
          }
        }

        return formattedMessages.join('\n');
      }

      if (messageCount == 1) {
        title = baseTitle;
        body = message.trimRight();
      } else {
        title = '$baseTitle ($messageCount)';
        body = formatAllMessages().trimRight();
      }

      // Truncate long messages
      if (body.length > 500) {
        body = '${body.substring(0, 497)}...';
      }

      // Create notification details with grouping
      final androidDetails = AndroidNotificationDetails(
        _notificationChannelId,
        _notificationChannelName,
        importance: Importance.high,
        showWhen: true,
        enableLights: true,
        playSound: true,
        enableVibration: true,
        icon: '@drawable/ic_notification',
        groupKey: groupId, // Group notifications by conversation
        setAsGroupSummary: false, // This is not the summary notification
        styleInformation: const BigTextStyleInformation(''), // Will be set below
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        threadIdentifier: groupId, // Group notifications on iOS
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Use group ID as notification ID to update existing notifications
      final notificationId = groupId.hashCode;

      await _notifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: jsonEncode({
          'group_id': groupId,
          'message_count': _groupMessageCounts[groupId],
          'latest_message': latestMessage,
        }),
      );

      // Don't create summary notification - just keep one notification per chat group

      debugPrint('📱 [WebSocket] Grouped notification shown for $groupId: $title - ${_groupMessageCounts[groupId]} messages');
    } catch (e) {
      debugPrint('❌ [WebSocket] Error showing notification: $e');
    }
  }


  /// Clear notifications for a specific group (when user opens the conversation)
  static Future<void> clearGroupNotifications(String groupId) async {
    try {
      // Remove from tracking
      _groupedMessages.remove(groupId);
      _groupMessageCounts.remove(groupId);

      // Cancel the specific notification
      await _notifications.cancel(groupId.hashCode);

      debugPrint('📱 [WebSocket] Cleared notifications for group: $groupId');
    } catch (e) {
      debugPrint('❌ [WebSocket] Error clearing group notifications: $e');
    }
  }

  /// Clear all notifications
  static Future<void> clearAllNotifications() async {
    try {
      _groupedMessages.clear();
      _groupMessageCounts.clear();
      await _notifications.cancelAll();
      debugPrint('📱 [WebSocket] Cleared all notifications');
    } catch (e) {
      debugPrint('❌ [WebSocket] Error clearing all notifications: $e');
    }
  }

  /// Get notification count for a specific group
  static int getGroupNotificationCount(String groupId) {
    return _groupMessageCounts[groupId] ?? 0;
  }

  /// Get total notification count across all groups
  static int getTotalNotificationCount() {
    return _groupMessageCounts.values.fold(0, (sum, count) => sum + count);
  }

  /// Check if a group has unread notifications
  static bool hasUnreadNotifications(String groupId) {
    return _groupMessageCounts.containsKey(groupId) && _groupMessageCounts[groupId]! > 0;
  }
}
