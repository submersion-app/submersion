import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/keychain_gated_authenticator.dart';
import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

import '../../../../support/fake_keychain_storage.dart';

/// Records which delegate the gate picked and that calls reach it.
class _FakeAuthenticator implements GoogleDriveAuthenticator {
  _FakeAuthenticator(this.label);

  final String label;
  final http.Client client = http.Client();

  int authenticateCalls = 0;
  int silentAuthCalls = 0;
  int signOutCalls = 0;
  int authFailureCalls = 0;
  bool silentAuthResult = true;
  bool exposeClient = false;

  @override
  http.Client? get authClient => exposeClient ? client : null;

  @override
  Future<void> authenticate() async => authenticateCalls++;

  @override
  Future<bool> attemptSilentAuth() async {
    silentAuthCalls++;
    return silentAuthResult;
  }

  @override
  Future<void> handleAuthFailure() async => authFailureCalls++;

  @override
  Future<void> signOut() async => signOutCalls++;

  @override
  Future<String?> get userEmail async => '$label@example.com';
}

void main() {
  late _FakeAuthenticator loopback;
  late _FakeAuthenticator googleSignIn;

  setUp(() {
    loopback = _FakeAuthenticator('loopback');
    googleSignIn = _FakeAuthenticator('gsi');
  });

  KeychainGatedAuthenticator gateOver(
    FallbackSecureStorage storage, {
    bool desktopClientConfigured = true,
  }) => KeychainGatedAuthenticator(
    legacyKeychainRequired: storage.legacyKeychainRequired,
    desktopClientConfigured: () => desktopClientConfigured,
    loopbackAuthenticator: () => loopback,
    googleSignInAuthenticator: () => googleSignIn,
  );

  group('delegate selection', () {
    test('uses the loopback flow when the data-protection keychain is '
        'unavailable (the Developer ID DMG)', () async {
      final gate = gateOver(FallbackSecureStorage(NoEntitlementKeychain()));

      await gate.authenticate();

      expect(loopback.authenticateCalls, 1);
      expect(googleSignIn.authenticateCalls, 0);
    });

    test('uses google_sign_in when the data-protection keychain works '
        '(App Store / iOS)', () async {
      final gate = gateOver(FallbackSecureStorage(InMemoryKeychain()));

      await gate.authenticate();

      expect(googleSignIn.authenticateCalls, 1);
      expect(loopback.authenticateCalls, 0);
    });

    test(
      'falls back to google_sign_in when the probe fails outright',
      () async {
        var probes = 0;
        final gate = KeychainGatedAuthenticator(
          legacyKeychainRequired: () async {
            probes++;
            throw PlatformException(code: 'boom', details: -25308);
          },
          desktopClientConfigured: () => true,
          loopbackAuthenticator: () => loopback,
          googleSignInAuthenticator: () => googleSignIn,
        );

        await gate.authenticate();
        await gate.authenticate();

        expect(googleSignIn.authenticateCalls, 2);
        expect(loopback.authenticateCalls, 0);
        // An unreadable keychain is memoised like any other verdict, so a
        // single process never flaps between two auth backends.
        expect(probes, 1);
      },
    );
    group('keychain unavailable AND no Desktop client secret', () {
      // Neither backend can work: google_sign_in dies in the keychain and the
      // loopback exchange has no secret. Routing to google_sign_in anyway
      // would reproduce the misleading "keychain error" this gate exists to
      // eliminate, so the gate names the real cause instead.
      KeychainGatedAuthenticator unconfiguredGate() => gateOver(
        FallbackSecureStorage(NoEntitlementKeychain()),
        desktopClientConfigured: false,
      );

      test('authenticate throws naming the missing define', () async {
        final gate = unconfiguredGate();

        await expectLater(
          gate.authenticate(),
          throwsA(
            isA<CloudStorageException>().having(
              (e) => e.message,
              'message',
              contains('GOOGLE_DRIVE_CLIENT_SECRET'),
            ),
          ),
        );
      });

      test('it does not route to an authenticator that cannot work', () async {
        final gate = unconfiguredGate();

        await gate.attemptSilentAuth();

        expect(googleSignIn.authenticateCalls, 0);
        expect(googleSignIn.silentAuthCalls, 0);
        expect(loopback.authenticateCalls, 0);
        expect(loopback.silentAuthCalls, 0);
      });

      test(
        'attemptSilentAuth reports not-signed-in without throwing',
        () async {
          final gate = unconfiguredGate();

          expect(await gate.attemptSilentAuth(), isFalse);
          expect(gate.authClient, isNull);
          expect(await gate.userEmail, isNull);
        },
      );

      test('signOut and handleAuthFailure are inert', () async {
        final gate = unconfiguredGate();

        // Must not throw: both run on paths that treat failure as fatal.
        await gate.signOut();
        await gate.handleAuthFailure();
      });
    });
  });

  group('laziness', () {
    test('does not probe the keychain at construction', () async {
      final keychain = NoEntitlementKeychain();
      gateOver(FallbackSecureStorage(keychain));

      await Future<void>.delayed(Duration.zero);

      expect(keychain.dataProtectionAttempted, isFalse);
    });

    test('probes at most once across concurrent first calls', () async {
      var probes = 0;
      final gate = KeychainGatedAuthenticator(
        legacyKeychainRequired: () async {
          probes++;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return true;
        },
        desktopClientConfigured: () => true,
        loopbackAuthenticator: () => loopback,
        googleSignInAuthenticator: () => googleSignIn,
      );

      await Future.wait([
        gate.authenticate(),
        gate.attemptSilentAuth(),
        gate.userEmail,
      ]);

      expect(probes, 1);
    });

    test('builds the unselected authenticator not at all', () async {
      var loopbackBuilds = 0;
      var googleSignInBuilds = 0;
      final gate = KeychainGatedAuthenticator(
        legacyKeychainRequired: () async => false,
        desktopClientConfigured: () => true,
        loopbackAuthenticator: () {
          loopbackBuilds++;
          return loopback;
        },
        googleSignInAuthenticator: () {
          googleSignInBuilds++;
          return googleSignIn;
        },
      );

      await gate.attemptSilentAuth();

      expect(loopbackBuilds, 0, reason: 'must not bind a loopback socket');
      expect(googleSignInBuilds, 1);
    });
  });

  group('forwarding', () {
    test('authClient is null before resolution, the delegate after', () async {
      final gate = gateOver(FallbackSecureStorage(NoEntitlementKeychain()));
      loopback.exposeClient = true;

      expect(gate.authClient, isNull);
      await gate.attemptSilentAuth();

      expect(gate.authClient, same(loopback.client));
    });

    test('forwards every seam method to the chosen delegate', () async {
      final gate = gateOver(FallbackSecureStorage(NoEntitlementKeychain()));
      loopback.silentAuthResult = false;

      expect(await gate.attemptSilentAuth(), isFalse);
      expect(await gate.userEmail, 'loopback@example.com');
      await gate.handleAuthFailure();
      await gate.signOut();

      expect(loopback.silentAuthCalls, 1);
      expect(loopback.authFailureCalls, 1);
      expect(loopback.signOutCalls, 1);
    });

    test('attemptSilentAuth never throws when resolution fails', () async {
      final gate = KeychainGatedAuthenticator(
        legacyKeychainRequired: () async => throw StateError('probe exploded'),
        desktopClientConfigured: () => true,
        loopbackAuthenticator: () => loopback,
        googleSignInAuthenticator: () => throw StateError('build exploded'),
      );

      expect(await gate.attemptSilentAuth(), isFalse);
    });
  });
}
