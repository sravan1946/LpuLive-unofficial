// Dart imports:
import 'dart:io';

// Package imports:
import 'package:path_provider/path_provider.dart';

class FileSaveResult {
  final String filePath;
  final String locationLabel;

  const FileSaveResult({
    required this.filePath,
    required this.locationLabel,
  });
}

class FileSaverService {
  static const List<String> _androidDownloadPaths = [
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Downloads',
    '/sdcard/Download',
    '/sdcard/Downloads',
  ];

  static Future<FileSaveResult> copyFileToBestLocation({
    required File sourceFile,
    required String fileName,
    Future<bool> Function()? requestPermission,
  }) async {
    final sanitizedName = _sanitizeFileName(fileName);

    final directResult =
        Platform.isAndroid ? await _tryStandardDownloads(sourceFile, sanitizedName) : null;
    if (directResult != null) {
      return directResult;
    }

    if (Platform.isAndroid && requestPermission != null) {
      final granted = await requestPermission();
      if (granted) {
        final retryResult = await _tryStandardDownloads(sourceFile, sanitizedName);
        if (retryResult != null) {
          return retryResult;
        }
      }
    }

    return _saveToFallback(sourceFile, sanitizedName);
  }

  static Future<FileSaveResult> saveBytesToBestLocation({
    required List<int> bytes,
    required String fileName,
    Future<bool> Function()? requestPermission,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final tempName =
        '${DateTime.now().millisecondsSinceEpoch}_${_sanitizeFileName(fileName)}';
    final tempFile = File('${tempDir.path}/$tempName');
    await tempFile.writeAsBytes(bytes);

    try {
      return await copyFileToBestLocation(
        sourceFile: tempFile,
        fileName: fileName,
        requestPermission: requestPermission,
      );
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  static Future<FileSaveResult?> _tryStandardDownloads(
    File sourceFile,
    String fileName,
  ) async {
    for (final path in _androidDownloadPaths) {
      try {
        final dir = Directory(path);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final targetFile = File('${dir.path}/$fileName');
        await sourceFile.copy(targetFile.path);
        return FileSaveResult(
          filePath: targetFile.path,
          locationLabel: 'Downloads folder',
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static Future<FileSaveResult> _saveToFallback(
    File sourceFile,
    String fileName,
  ) async {
    if (Platform.isAndroid) {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final fallbackDir = Directory('${externalDir.path}/Download');
        if (!await fallbackDir.exists()) {
          await fallbackDir.create(recursive: true);
        }
        final targetFile = File('${fallbackDir.path}/$fileName');
        await sourceFile.copy(targetFile.path);
        return FileSaveResult(
          filePath: targetFile.path,
          locationLabel: 'External storage',
        );
      }
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final targetFile = File('${docsDir.path}/$fileName');
    await sourceFile.copy(targetFile.path);
    return FileSaveResult(
      filePath: targetFile.path,
      locationLabel: Platform.isIOS ? 'Files app' : 'App storage',
    );
  }

  static String _sanitizeFileName(String name) {
    final trimmed = name.trim().isEmpty ? 'downloaded_file' : name.trim();
    return trimmed.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }
}
