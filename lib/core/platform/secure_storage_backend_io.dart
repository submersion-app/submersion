import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/secure_storage/legacy_keychain_options.dart';

/// Native backend over [FlutterSecureStorage] that uses the macOS legacy
/// (file-based) keychain when the default data-protection keychain is
/// unavailable.
///
/// The no-sandbox (GitHub-distribution) build is Developer-ID signed with no
/// provisioning profile, so it has no keychain access group and the
/// data-protection keychain rejects modifying ops with
/// `errSecMissingEntitlement` (-34018). The legacy file-based keychain needs
/// no access group on a non-sandboxed app. Sandboxed (App Store) / iOS
/// builds get their access group from the provisioning profile and must NOT
/// touch the file-based keychain: the sandbox forbids it.
///
/// A keychain *read* returns "item not found" (null) rather than -34018 when
/// the access group is missing, so per-operation error handling cannot tell
/// which keychain to use on a read (this is why an earlier read-side -34018
/// fallback silently failed). Instead this **probes once**, with a throwaway
/// write to the data-protection keychain, which raises -34018 iff that
/// keychain is unavailable, caches the verdict, and routes every
/// read/write/delete to the keychain that works. `mOptions` is ignored on
/// non-macOS platforms, so the probe simply succeeds there and the default
/// keychain is used.
class SecureStorageBackend {
  SecureStorageBackend(this._storage);

  final FlutterSecureStorage _storage;

  /// `errSecMissingEntitlement`: "a required entitlement isn't present".
  static const int _errSecMissingEntitlement = -34018;

  /// Throwaway key used to probe data-protection-keychain availability.
  static const String _probeKey = '__submersion_keychain_probe__';

  /// Memoised probe: resolves `true` once the data-protection keychain is
  /// known to be unavailable (the no-sandbox build). The same [Future] is
  /// shared by concurrent first callers, so the probe runs at most once.
  Future<bool>? _useLegacy;

  /// Whether this build must use the legacy file-based keychain, i.e.
  /// whether the data-protection keychain rejects writes with -34018.
  Future<bool> legacyKeychainRequired() => _useLegacy ??= _probe();

  Future<bool> _probe() async {
    try {
      await _storage.write(key: _probeKey, value: '1');
      await _storage.delete(key: _probeKey);
      return false;
    } on PlatformException catch (e) {
      if (e.details == _errSecMissingEntitlement) return true;
      rethrow;
    }
  }

  Future<String?> read(String key) async {
    if (await legacyKeychainRequired()) {
      return _storage.read(key: key, mOptions: legacyKeychainMacOsOptions);
    }
    return _storage.read(key: key);
  }

  Future<void> write(String key, String value) async {
    if (await legacyKeychainRequired()) {
      return _storage.write(
        key: key,
        value: value,
        mOptions: legacyKeychainMacOsOptions,
      );
    }
    return _storage.write(key: key, value: value);
  }

  Future<void> delete(String key) async {
    if (await legacyKeychainRequired()) {
      return _storage.delete(key: key, mOptions: legacyKeychainMacOsOptions);
    }
    return _storage.delete(key: key);
  }

  /// Native credentials always outlive the app in the keychain; there is
  /// no session store to move them to, so the switch reads off and does
  /// nothing.
  static bool get remember => false;

  static Future<void> setRemember(bool value) async {}

  /// Forget this device is a browser action; a native device removes its
  /// credentials store by store.
  static Future<void> clearAll() async =>
      throw UnsupportedError('clearAll is the browser\'s Forget this device');
}
