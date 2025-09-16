// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:shared_preferences/shared_preferences.dart';

class AvatarCacheService {
  static const String _kAvatarCacheKey = 'avatar_cache_v1';
  static final Map<String, String> _avatarCache = {};
  static bool _isLoaded = false;

  /// Load avatar cache from persistent storage
  static Future<void> loadCache() async {
    if (_isLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kAvatarCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(raw);
        _avatarCache.clear();
        for (final entry in data.entries) {
          final userId = entry.key;
          final avatarUrl = entry.value?.toString();
          if (avatarUrl != null && avatarUrl.isNotEmpty) {
            _avatarCache[userId] = avatarUrl;
          }
        }
      }
    } catch (e) {
      // Ignore errors and continue with empty cache
    } finally {
      _isLoaded = true;
    }
  }

  /// Get cached avatar URL for a user
  static String? getCachedAvatar(String userId) {
    return _avatarCache[userId];
  }

  /// Cache avatar URL for a user
  static Future<void> cacheAvatar(String userId, String? avatarUrl) async {
    if (userId.isEmpty || avatarUrl == null || avatarUrl.isEmpty) return;

    final existing = _avatarCache[userId];
    if (existing == avatarUrl) return;

    _avatarCache[userId] = avatarUrl;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAvatarCacheKey, jsonEncode(_avatarCache));
    } catch (e) {
      // Ignore errors - cache will still work in memory
    }
  }

  /// Check if we have a cached avatar for a user
  static bool hasCachedAvatar(String userId) {
    return _avatarCache.containsKey(userId) &&
        _avatarCache[userId] != null &&
        _avatarCache[userId]!.isNotEmpty;
  }

  /// Get all cached avatars (for debugging or bulk operations)
  static Map<String, String> getAllCachedAvatars() {
    return Map.from(_avatarCache);
  }

  /// Clear all cached avatars
  static Future<void> clearCache() async {
    _avatarCache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAvatarCacheKey);
    } catch (e) {
      // Ignore errors
    }
  }

  /// Get cache size (for debugging)
  static int getCacheSize() {
    return _avatarCache.length;
  }
}
