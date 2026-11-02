import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_client_config.dart';

void main() {
  group('desktopClientConfigured', () {
    // The loopback flow needs BOTH halves. Google authenticates the token
    // exchange for Desktop-app clients with the client secret and rejects the
    // request outright without it (`invalid_request: client_secret is
    // missing`), PKCE notwithstanding -- so a build carrying only the client
    // id can never complete sign-in and must not advertise Drive.
    test('requires both the client id and the secret', () {
      expect(
        GoogleDriveClientConfig.desktopClientConfigured('id', 'secret'),
        isTrue,
      );
    });

    test('is false with an id but no secret', () {
      expect(
        GoogleDriveClientConfig.desktopClientConfigured('id', ''),
        isFalse,
        reason: 'a secretless build cannot exchange the auth code',
      );
    });

    test('is false with a secret but no id', () {
      expect(
        GoogleDriveClientConfig.desktopClientConfigured('', 'secret'),
        isFalse,
      );
    });

    test('is false with neither', () {
      expect(GoogleDriveClientConfig.desktopClientConfigured('', ''), isFalse);
    });
  });

  group('committed configuration', () {
    test('the desktop client id is compiled in', () {
      expect(GoogleDriveClientConfig.desktopClientId, isNotEmpty);
    });

    test('the secret is build-time only, never committed', () {
      // Guards the repo rule: the value arrives via
      // --dart-define=GOOGLE_DRIVE_CLIENT_SECRET, so a plain `flutter test`
      // must see it absent. If this ever fails, a secret was hardcoded.
      const hardcoded = String.fromEnvironment(
        'GOOGLE_DRIVE_CLIENT_SECRET',
        defaultValue: '__unset__',
      );
      expect(
        GoogleDriveClientConfig.desktopClientSecret,
        hardcoded == '__unset__' ? '' : hardcoded,
      );
    });
  });

  group('supportedOn (#4121)', () {
    test('a browser offers Drive whatever OS it runs on', () {
      expect(
        GoogleDriveClientConfig.supportedOn(
          web: true,
          loopbackPlatform: true,
          hasDesktopClient: false,
        ),
        isTrue,
      );
    });

    test('a native loopback platform still needs the desktop client', () {
      expect(
        GoogleDriveClientConfig.supportedOn(
          web: false,
          loopbackPlatform: true,
          hasDesktopClient: false,
        ),
        isFalse,
      );
      expect(
        GoogleDriveClientConfig.supportedOn(
          web: false,
          loopbackPlatform: true,
          hasDesktopClient: true,
        ),
        isTrue,
      );
    });

    test('phones and Macs never needed it', () {
      expect(
        GoogleDriveClientConfig.supportedOn(
          web: false,
          loopbackPlatform: false,
          hasDesktopClient: false,
        ),
        isTrue,
      );
    });
  });
}
