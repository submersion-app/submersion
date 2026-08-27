import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

import '../../../support/fake_keychain_storage.dart';

void main() {
  group('data-protection keychain available (sandboxed / profiled build)', () {
    test('read / write / delete use the default keychain', () async {
      final inner = InMemoryKeychain();
      final storage = FallbackSecureStorage(inner);

      await storage.write(key: 'k', value: 'v');
      expect(await storage.read(key: 'k'), 'v');

      await storage.delete(key: 'k');
      expect(await storage.read(key: 'k'), isNull);
    });
  });

  group('data-protection keychain unavailable (no-sandbox build)', () {
    test('write then read round-trips through the legacy keychain', () async {
      // Regression guard: the data-protection keychain throws on writes but
      // returns not-found (null) on reads, so a read-side -34018 fallback never
      // fires and the saved value is unreadable. This fails on the old design.
      final inner = NoEntitlementKeychain();
      final storage = FallbackSecureStorage(inner);

      await storage.write(key: 'k', value: 'v');

      expect(await storage.read(key: 'k'), 'v');
      expect(inner.legacy['k'], 'v');
      expect(inner.dataProtectionAttempted, isTrue);
    });

    test('reads a value already in the legacy keychain (cross-launch)', () async {
      // First operation of the "session" is a read of a previously-stored value;
      // the probe must establish the legacy keychain before that read.
      final inner = NoEntitlementKeychain()..legacy['k'] = 'v';
      final storage = FallbackSecureStorage(inner);

      expect(await storage.read(key: 'k'), 'v');
    });

    test('delete removes the value from the legacy keychain', () async {
      final inner = NoEntitlementKeychain()..legacy['k'] = 'v';
      final storage = FallbackSecureStorage(inner);

      await storage.delete(key: 'k');

      expect(inner.legacy.containsKey('k'), isFalse);
    });
  });

  test('a non-entitlement keychain error propagates', () async {
    final storage = FallbackSecureStorage(FailingKeychain(-25308));

    expect(storage.read(key: 'k'), throwsA(isA<PlatformException>()));
  });

  test('a non-entitlement error during the probe propagates', () async {
    final storage = FallbackSecureStorage(ProbeFailingKeychain(-25308));

    expect(storage.read(key: 'k'), throwsA(isA<PlatformException>()));
  });

  test(
    'legacy keychain options re-emit the native-read data-protection key',
    () {
      // flutter_secure_storage 10.x serialises the flag as
      // `usesDataProtectionKeychain`, but flutter_secure_storage_darwin 0.2.0
      // reads the differently-cased `useDataProtectionKeyChain` and defaults to
      // the data-protection keychain when it is absent.
      final map = FallbackSecureStorage.legacyKeychainOptions.toMap();

      expect(map['useDataProtectionKeyChain'], 'false');
    },
  );

  group('legacyKeychainRequired', () {
    // Google sign-in on macOS cannot be pointed at the legacy keychain, so
    // callers outside this wrapper need the verdict itself, not just routing.
    test('is false when the data-protection keychain accepts writes', () async {
      final storage = FallbackSecureStorage(InMemoryKeychain());

      expect(await storage.legacyKeychainRequired(), isFalse);
    });

    test('is true when the data-protection keychain is unentitled', () async {
      final storage = FallbackSecureStorage(NoEntitlementKeychain());

      expect(await storage.legacyKeychainRequired(), isTrue);
    });

    test('shares the memoised probe with read/write routing', () async {
      final keychain = _CountingKeychain();
      final storage = FallbackSecureStorage(keychain);

      await storage.legacyKeychainRequired();
      await storage.write(key: 'k', value: 'v');
      await storage.read(key: 'k');

      expect(keychain.dataProtectionWrites, 1, reason: 'probed once');
    });
  });
}

/// Counts data-protection writes so the memoisation is observable.
class _CountingKeychain extends NoEntitlementKeychain {
  int dataProtectionWrites = 0;

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
    final usesDataProtection =
        mOptions is! MacOsOptions || mOptions.usesDataProtectionKeychain;
    if (usesDataProtection) dataProtectionWrites++;
    return super.write(
      key: key,
      value: value,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }
}
