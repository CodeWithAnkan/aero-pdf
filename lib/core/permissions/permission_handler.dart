import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Handles storage permissions for Android 13+ (scoped storage).
///
/// On Android 13+ (SDK 33+): [file_picker] uses SAF (Storage Access Framework)
/// internally, so no runtime permission is needed for picking arbitrary files.
/// On Android < 13: we request [Permission.storage].
Future<bool> requestStoragePermission() async {
  if (!Platform.isAndroid) return true;

  try {
    final info = await DeviceInfoPlugin().androidInfo;
    final sdkInt = info.version.sdkInt;

    if (sdkInt >= 30) {
      // Android 11+ requires MANAGE_EXTERNAL_STORAGE for custom directory access
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }
      return status.isGranted;
    } else if (sdkInt >= 33) {
      // For picking files, no permission is needed on 13+, 
      // but for writing to public folders we might still need it.
      return true;
    } else {
      // Android < 11
      final status = await Permission.storage.request();
      return status.isGranted;
    }
  } catch (e) {
    debugPrint('[AeroPDF] Permission check failed: $e');
    return false;
  }
}

/// Opens the device app settings screen so the user can manually grant
/// permissions if they were previously denied with "Don't ask again".
Future<void> openPermissionSettings() => openAppSettings();
