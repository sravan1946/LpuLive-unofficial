// Dart imports:
import 'dart:io';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:permission_handler/permission_handler.dart';

// Project imports:
import '../widgets/app_toast.dart';

class StoragePermissionService {
  static Future<bool> ensureStoragePermission({
    required BuildContext context,
    required String deniedMessage,
    required String permanentlyDeniedMessage,
    String errorPrefix = 'Storage permission error',
  }) async {
    if (!Platform.isAndroid) {
      return true;
    }

    try {
      if (await _hasStorageAccess()) {
        return true;
      }

      // First request legacy storage permission
      final storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted) {
        return true;
      }

      if (storageStatus.isPermanentlyDenied) {
        showAppToast(context, permanentlyDeniedMessage, type: ToastType.error);
        await openAppSettings();
        return false;
      }

      // For Android 11+ request manage external storage
      final manageStatus = await Permission.manageExternalStorage.request();
      if (manageStatus.isGranted) {
        return true;
      }

      showAppToast(
        context,
        manageStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied
            ? permanentlyDeniedMessage
            : deniedMessage,
        type: manageStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied
            ? ToastType.error
            : ToastType.warning,
      );

      if (manageStatus.isPermanentlyDenied) {
        await openAppSettings();
      }

      return false;
    } catch (e) {
      showAppToast(
        context,
        '$errorPrefix: $e',
        type: ToastType.error,
      );
      return false;
    }
  }

  static Future<bool> _hasStorageAccess() async {
    final storageGranted = await Permission.storage.isGranted;
    if (storageGranted) return true;

    final manageGranted = await Permission.manageExternalStorage.isGranted;
    return manageGranted;
  }
}
