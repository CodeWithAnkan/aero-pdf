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
    if (info.version.sdkInt >= 33) {
      // SAF handles its own intent — no manifest permission needed
      return true;
    }
    final status = await Permission.storage.request();
    return status.isGranted;
  } catch (e) {
    debugPrint('[AeroPDF] Permission check failed: $e');
    return false;
  }
}

/// Opens the device app settings screen so the user can manually grant
/// permissions if they were previously denied with "Don't ask again".
Future<void> openPermissionSettings() => openAppSettings();
