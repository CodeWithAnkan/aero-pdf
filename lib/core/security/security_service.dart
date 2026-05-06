import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  SecurityService._();
  
  static final LocalAuthentication _auth = LocalAuthentication();
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Prompts for biometric authentication. Returns true if successful.
  static Future<bool> authenticate() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) return true; // Fallback if no biometrics available

      return await _auth.authenticate(
        localizedReason: 'Please authenticate to access saved passwords',
      );
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Saves a password for a specific book ID.
  static Future<void> savePassword(int bookId, String password) async {
    await _storage.write(key: 'pdf_pwd_$bookId', value: password);
  }

  /// Retrieves a password for a specific book ID.
  static Future<String?> getPassword(int bookId) async {
    return await _storage.read(key: 'pdf_pwd_$bookId');
  }

  /// Deletes a password for a specific book ID.
  static Future<void> deletePassword(int bookId) async {
    await _storage.delete(key: 'pdf_pwd_$bookId');
  }

  /// Checks if a password exists for a book ID.
  static Future<bool> hasPassword(int bookId) async {
    final pwd = await getPassword(bookId);
    return pwd != null;
  }
}
