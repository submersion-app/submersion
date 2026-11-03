import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/platform/web/browser_local_storage.dart';
import 'package:submersion/core/platform/web/web_secure_storage_core.dart';

/// Browser backend: one [WebSecureStorageCore] over `window.localStorage`
/// for the whole page, so every credentials store shares the session store
/// and the remember switch. The [FlutterSecureStorage] a store was given is
/// ignored; there is no keychain here.
class SecureStorageBackend {
  SecureStorageBackend(FlutterSecureStorage _);

  /// The page's one store.
  static final WebSecureStorageCore core = WebSecureStorageCore(
    localStorage: BrowserLocalStorage(),
  );

  /// No keychain, so no legacy keychain either.
  Future<bool> legacyKeychainRequired() async => false;

  Future<String?> read(String key) => core.read(key);

  Future<void> write(String key, String value) => core.write(key, value);

  Future<void> delete(String key) => core.delete(key);

  static bool get remember => core.remember;

  static Future<void> setRemember(bool value) => core.setRemember(value);

  /// Forget this device: every credential and the remember flag.
  static Future<void> clearAll() => core.clearAll();
}
