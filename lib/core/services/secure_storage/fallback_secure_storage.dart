import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper over [FlutterSecureStorage] that uses the macOS legacy (file-based)
/// keychain when the default data-protection keychain is unavailable.
///
/// The no-sandbox (GitHub-distribution) build is Developer-ID signed with no
/// provisioning profile, so it has no keychain access group and the
/// data-protection keychain rejects modifying ops with
/// `errSecMissingEntitlement` (-34018). The legacy file-based keychain needs no
/// access group on a non-sandboxed app. Sandboxed (App Store) / iOS builds get
/// their access group from the provisioning profile and must NOT touch the
/// file-based keychain -- the sandbox forbids it.
///
/// A keychain *read* returns "item not found" (null) rather than -34018 when the
/// access group is missing, so per-operation error handling cannot tell which
/// keychain to use on a read (this is why an earlier read-side -34018 fallback
/// silently failed). Instead this **probes once** -- a throwaway write to the
/// data-protection keychain, which raises -34018 iff that keychain is
/// unavailable -- caches the verdict, and routes every read/write/delete to the
/// keychain that works. `mOptions` is ignored on non-macOS platforms, so the
/// probe simply succeeds there and the default keychain is used.
class FallbackSecureStorage {
  FallbackSecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  /// `errSecMissingEntitlement` -- "a required entitlement isn't present".
  static const int _errSecMissingEntitlement = -34018;

  /// Throwaway key used to probe data-protection-keychain availability.
  static const String _probeKey = '__submersion_keychain_probe__';

  /// Options that select the legacy file-based keychain.
  ///
  /// Exposed for the regression test asserting the native-read key is present
  /// (see [_LegacyKeychainMacOsOptions]).
  @visibleForTesting
  static const MacOsOptions legacyKeychainOptions =
      _LegacyKeychainMacOsOptions();

  /// Memoised probe: resolves `true` once the data-protection keychain is known
  /// to be unavailable (the no-sandbox build). The same [Future] is shared by
  /// concurrent first callers, so the probe runs at most once.
  Future<bool>? _useLegacy;

  Future<bool> _legacyKeychainRequired() => _useLegacy ??= _probe();

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

  Future<String?> read({required String key}) async {
    if (await _legacyKeychainRequired()) {
      return _storage.read(key: key, mOptions: legacyKeychainOptions);
    }
    return _storage.read(key: key);
  }

  Future<void> write({required String key, required String value}) async {
    if (await _legacyKeychainRequired()) {
      return _storage.write(
        key: key,
        value: value,
        mOptions: legacyKeychainOptions,
      );
    }
    return _storage.write(key: key, value: value);
  }

  Future<void> delete({required String key}) async {
    if (await _legacyKeychainRequired()) {
      return _storage.delete(key: key, mOptions: legacyKeychainOptions);
    }
    return _storage.delete(key: key);
  }
}

/// [MacOsOptions] that actually selects the legacy (non-data-protection)
/// keychain on `flutter_secure_storage` 10.x.
///
/// Upstream key mismatch: the Dart side serialises the flag under
/// `usesDataProtectionKeychain` (`MacOsOptions.toMap`), but the native
/// `flutter_secure_storage_darwin` 0.2.0 plugin reads it under the
/// differently-cased key `useDataProtectionKeyChain` and defaults to `true` when
/// that key is absent. So `MacOsOptions(usesDataProtectionKeychain: false)` is
/// silently dropped and the data-protection keychain is always used. We
/// additionally emit the value under the key the native layer actually reads.
/// Remove once the plugin keys agree
/// (https://github.com/juliansteenbakker/flutter_secure_storage).
class _LegacyKeychainMacOsOptions extends MacOsOptions {
  const _LegacyKeychainMacOsOptions()
    : super(usesDataProtectionKeychain: false);

  @override
  Map<String, String> toMap() => <String, String>{
    ...super.toMap(),
    'useDataProtectionKeyChain': 'false',
  };
}
