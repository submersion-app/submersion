import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// `errSecMissingEntitlement` -- the macOS Security framework status the
/// ad-hoc-signed no-sandbox build provokes from the data-protection keychain.
const int kErrSecMissingEntitlement = -34018;

bool _usesDataProtection(AppleOptions? mOptions) =>
    mOptions is MacOsOptions ? mOptions.usesDataProtectionKeychain : true;

/// An in-memory keychain that ignores `mOptions` -- both keychains behave
/// identically, modelling a normally-entitled build where no fallback runs.
class InMemoryKeychain extends Fake implements FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}

/// Models the ad-hoc-signed no-sandbox macOS build: the data-protection
/// keychain (default / `usesDataProtectionKeychain: true`) throws
/// `errSecMissingEntitlement`, while the legacy keychain
/// (`usesDataProtectionKeychain: false`) works against [legacy].
class NoEntitlementKeychain extends Fake implements FlutterSecureStorage {
  /// Backing store standing in for the legacy (file-based) keychain.
  final Map<String, String> legacy = {};

  /// Set once the data-protection keychain has been attempted, proving the
  /// caller tries the secure keychain before falling back.
  bool dataProtectionAttempted = false;

  PlatformException _missing() => PlatformException(
    code: 'Unexpected security result code',
    message: "A required entitlement isn't present.",
    details: kErrSecMissingEntitlement,
  );

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (_usesDataProtection(mOptions)) {
      dataProtectionAttempted = true;
      throw _missing();
    }
    return legacy[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (_usesDataProtection(mOptions)) {
      dataProtectionAttempted = true;
      throw _missing();
    }
    if (value == null) {
      legacy.remove(key);
    } else {
      legacy[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (_usesDataProtection(mOptions)) {
      dataProtectionAttempted = true;
      throw _missing();
    }
    legacy.remove(key);
  }
}

/// A keychain that always throws a [PlatformException] carrying [status] on
/// read -- used to verify that errors other than the missing entitlement
/// propagate unchanged.
class FailingKeychain extends Fake implements FlutterSecureStorage {
  FailingKeychain(this.status);

  final int status;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw PlatformException(
    code: 'Unexpected security result code',
    message: 'interaction not allowed',
    details: status,
  );
}
