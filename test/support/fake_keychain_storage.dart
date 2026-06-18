import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// `errSecMissingEntitlement` -- the macOS Security framework status the
/// no-sandbox build provokes from the data-protection keychain (no access
/// group). Modifying ops raise it; reads return not-found (null) instead.
const int kErrSecMissingEntitlement = -34018;

bool _usesDataProtection(AppleOptions? mOptions) =>
    mOptions is MacOsOptions ? mOptions.usesDataProtectionKeychain : true;

PlatformException _securityError(int status, [String? message]) =>
    PlatformException(
      code: 'Unexpected security result code',
      message: message ?? "A required entitlement isn't present.",
      details: status,
    );

/// An in-memory keychain that ignores `mOptions` -- both keychains behave
/// identically, modelling a normally-entitled build where the probe succeeds
/// and no fallback is needed.
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

/// Models the no-sandbox macOS build, including the keychain's asymmetric
/// behaviour: the data-protection keychain (default /
/// `usesDataProtectionKeychain: true`) throws `errSecMissingEntitlement` on
/// **modifying** ops but returns **not-found (null)** on **reads**, while the
/// legacy keychain (`usesDataProtectionKeychain: false`) works against [legacy].
///
/// So a data-protection probe write throws (revealing the missing entitlement),
/// and the wrapper must route every op -- including reads -- to the legacy
/// keychain.
class NoEntitlementKeychain extends Fake implements FlutterSecureStorage {
  /// Backing store standing in for the legacy (file-based) keychain.
  final Map<String, String> legacy = {};

  /// Set once the data-protection keychain has been touched, proving the
  /// wrapper probes the secure keychain before routing to the legacy one.
  bool dataProtectionAttempted = false;

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
      // Real keychain behaviour: a read with no access group returns not-found,
      // NOT errSecMissingEntitlement. This is the asymmetry that defeated the
      // read-side -34018 fallback.
      return null;
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
      throw _securityError(kErrSecMissingEntitlement);
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
      throw _securityError(kErrSecMissingEntitlement);
    }
    legacy.remove(key);
  }
}

/// A keychain whose probe (write/delete) succeeds but whose **read** always
/// throws [status] -- used to verify that errors other than the missing
/// entitlement propagate unchanged.
class FailingKeychain extends Fake implements FlutterSecureStorage {
  FailingKeychain(this.status);

  final int status;

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
  }) async {}

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {}

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw _securityError(status, 'interaction not allowed');
}

/// A keychain whose **probe write** throws [status] -- used to verify a
/// non-entitlement failure during the probe propagates rather than being
/// mistaken for "data-protection unavailable".
class ProbeFailingKeychain extends Fake implements FlutterSecureStorage {
  ProbeFailingKeychain(this.status);

  final int status;

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
  }) async => throw _securityError(status, 'interaction not allowed');
}
