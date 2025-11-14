// Dart imports:
import 'dart:convert';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Service to check for app updates from GitHub releases
class UpdateCheckerService {
  // GitHub repository for releases (lpulive-builds as mentioned in README)
  static const String _githubOwner = 'sravan1946';
  static const String _githubRepo = 'lpulive-builds';
  static const String _githubApiBase = 'https://api.github.com';

  /// Check if a newer version is available
  /// Returns [UpdateInfo] if update is available, null otherwise
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      debugPrint('🔍 [UpdateChecker] Checking for updates...');

      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      debugPrint('📱 [UpdateChecker] Current version: $currentVersion');

      // Fetch latest release from GitHub
      final latestRelease = await _fetchLatestRelease();
      if (latestRelease == null) {
        debugPrint('⚠️ [UpdateChecker] No releases found');
        return null;
      }

      debugPrint('📦 [UpdateChecker] Latest release: ${latestRelease.version}');

      // Compare versions
      if (_isNewerVersion(latestRelease.version, currentVersion)) {
        debugPrint('✅ [UpdateChecker] Update available: ${latestRelease.version}');
        return latestRelease;
      } else {
        debugPrint('✅ [UpdateChecker] App is up to date');
        return null;
      }
    } catch (e) {
      debugPrint('❌ [UpdateChecker] Error checking for updates: $e');
      return null;
    }
  }

  /// Fetch the latest release from GitHub
  static Future<UpdateInfo?> _fetchLatestRelease() async {
    try {
      final url = Uri.parse(
        '$_githubApiBase/repos/$_githubOwner/$_githubRepo/releases/latest',
      );

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'LPULive-App',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tagName = data['tag_name'] as String?;
        final name = data['name'] as String?;
        final body = data['body'] as String?;
        final htmlUrl = data['html_url'] as String?;
        final publishedAt = data['published_at'] as String?;

        // Find APK asset for Android
        String? downloadUrl;
        if (data['assets'] != null) {
          final assets = data['assets'] as List<dynamic>;
          for (final asset in assets) {
            final assetMap = asset as Map<String, dynamic>;
            final assetName = assetMap['browser_download_url'] as String?;
            if (assetName != null && assetName.endsWith('.apk')) {
              downloadUrl = assetName;
              break;
            }
          }
        }

        if (tagName != null) {
          // Remove 'v' prefix if present (e.g., "v1.0.5" -> "1.0.5")
          final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;

          return UpdateInfo(
            version: version,
            name: name ?? tagName,
            releaseNotes: body ?? '',
            downloadUrl: downloadUrl ?? htmlUrl ?? '',
            releaseUrl: htmlUrl ?? '',
            publishedAt: publishedAt ?? '',
          );
        }
      } else if (response.statusCode == 404) {
        debugPrint('⚠️ [UpdateChecker] Repository or releases not found');
      } else {
        debugPrint(
          '⚠️ [UpdateChecker] Failed to fetch release: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('❌ [UpdateChecker] Error fetching latest release: $e');
    }
    return null;
  }

  /// Compare two version strings
  /// Returns true if version1 is newer than version2
  static bool _isNewerVersion(String version1, String version2) {
    try {
      final v1Parts = version1.split('.').map(int.parse).toList();
      final v2Parts = version2.split('.').map(int.parse).toList();

      // Pad shorter version with zeros
      while (v1Parts.length < v2Parts.length) {
        v1Parts.add(0);
      }
      while (v2Parts.length < v1Parts.length) {
        v2Parts.add(0);
      }

      // Compare each part
      for (int i = 0; i < v1Parts.length; i++) {
        if (v1Parts[i] > v2Parts[i]) {
          return true;
        } else if (v1Parts[i] < v2Parts[i]) {
          return false;
        }
      }

      return false; // Versions are equal
    } catch (e) {
      debugPrint('❌ [UpdateChecker] Error comparing versions: $e');
      return false;
    }
  }
}

/// Information about an available update
class UpdateInfo {
  final String version;
  final String name;
  final String releaseNotes;
  final String downloadUrl;
  final String releaseUrl;
  final String publishedAt;

  UpdateInfo({
    required this.version,
    required this.name,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.releaseUrl,
    required this.publishedAt,
  });

  @override
  String toString() {
    return 'UpdateInfo(version: $version, name: $name, downloadUrl: $downloadUrl)';
  }
}
