import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/platform/secure_storage_backend.dart';
import 'package:submersion/core/services/secure_storage/legacy_keychain_options.dart';

/// The secure storage every credentials store writes through.
///
/// Natively a wrapper over [FlutterSecureStorage] that uses the macOS legacy
/// (file-based) keychain when the default data-protection keychain is
/// unavailable; in a browser a session store that local storage takes over
/// once the user asks to be remembered. [SecureStorageBackend] holds each
/// build's behaviour and the reasoning behind the keychain probe.
class FallbackSecureStorage {
  FallbackSecureStorage(FlutterSecureStorage storage)
    : _backend = SecureStorageBackend(storage);

  final SecureStorageBackend _backend;

  /// Options that select the legacy file-based keychain.
  ///
  /// Exposed for the regression test asserting the native-read key is
  /// present (see [LegacyKeychainMacOsOptions]).
  @visibleForTesting
  static const MacOsOptions legacyKeychainOptions = legacyKeychainMacOsOptions;

  /// Whether this build must use the legacy file-based keychain, i.e.
  /// whether the data-protection keychain rejects writes with -34018. False
  /// in a browser, which has no keychain at all.
  ///
  /// Public because the verdict also decides things outside this wrapper:
  /// google_sign_in hard-codes the data-protection keychain on macOS and
  /// exposes no way to change it, so a build that fails this probe cannot
  /// use the native Google sign-in flow at all (see
  /// KeychainGatedAuthenticator). Shares the memoised probe, so asking costs
  /// at most one throwaway write per instance.
  Future<bool> legacyKeychainRequired() => _backend.legacyKeychainRequired();

  Future<String?> read({required String key}) => _backend.read(key);

  Future<void> write({required String key, required String value}) =>
      _backend.write(key, value);

  Future<void> delete({required String key}) => _backend.delete(key);
}
