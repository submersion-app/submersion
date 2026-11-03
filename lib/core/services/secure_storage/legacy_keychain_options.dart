import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// [MacOsOptions] that actually selects the legacy (non-data-protection)
/// keychain on `flutter_secure_storage` 10.x.
///
/// Upstream key mismatch: the Dart side serialises the flag under
/// `usesDataProtectionKeychain` (`MacOsOptions.toMap`), but the native
/// `flutter_secure_storage_darwin` 0.2.0 plugin reads it under the
/// differently-cased key `useDataProtectionKeyChain` and defaults to `true`
/// when that key is absent. So `MacOsOptions(usesDataProtectionKeychain:
/// false)` is silently dropped and the data-protection keychain is always
/// used. We additionally emit the value under the key the native layer
/// actually reads. Remove once the plugin keys agree
/// (https://github.com/juliansteenbakker/flutter_secure_storage).
class LegacyKeychainMacOsOptions extends MacOsOptions {
  const LegacyKeychainMacOsOptions() : super(usesDataProtectionKeychain: false);

  @override
  Map<String, String> toMap() => <String, String>{
    ...super.toMap(),
    'useDataProtectionKeyChain': 'false',
  };
}

/// The options that select the legacy file-based keychain.
const MacOsOptions legacyKeychainMacOsOptions = LegacyKeychainMacOsOptions();
