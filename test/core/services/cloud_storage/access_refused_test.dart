import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_api_client.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_manager.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_store.dart';
import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';
import 'package:submersion/core/services/cloud_storage/google_drive_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';

import '../../../support/fake_keychain_storage.dart';

/// What counts as a refusal (issue #3811). Sync and backup ask a diver to
/// sign in again only for these, so the "not refused" half matters as much as
/// the other: an outage must never read as a sign-in problem.
void main() {
  Matcher refused(bool expected) => isA<CloudStorageException>().having(
    (e) => e.accessRefused,
    'accessRefused',
    expected,
  );

  test('a plain CloudStorageException is not a refusal', () {
    expect(const CloudStorageException('x').accessRefused, isFalse);
  });

  test('CloudAccessRefusedException is a refused CloudStorageException', () {
    const e = CloudAccessRefusedException('x', 'cause');
    expect(e, refused(true));
    expect(e.displayMessage, 'x (cause)');
  });

  group('Google Drive', () {
    GoogleDriveStorageProvider driveAnswering(int status, String reason) {
      final body = jsonEncode({
        'error': {
          'code': status,
          'message': 'refused',
          'errors': [
            {'reason': reason, 'message': 'refused', 'domain': 'global'},
          ],
        },
      });
      return GoogleDriveStorageProvider()..debugSetDriveApi(
        drive.DriveApi(
          MockClient(
            (_) async => http.Response(
              body,
              status,
              headers: {'content-type': 'application/json'},
            ),
          ),
        ),
      );
    }

    for (final reason in [
      'insufficientPermissions',
      'insufficientFilePermissions',
      'ACCESS_TOKEN_SCOPE_INSUFFICIENT',
      'authError',
    ]) {
      test('a 403 for $reason is a refusal', () async {
        await expectLater(
          driveAnswering(403, reason).listFiles(namePattern: 'ssv1.'),
          throwsA(refused(true)),
        );
      });
    }

    for (final reason in [
      'storageQuotaExceeded',
      'rateLimitExceeded',
      'userRateLimitExceeded',
      'somethingNew',
    ]) {
      test('a 403 for $reason is not a refusal', () async {
        await expectLater(
          driveAnswering(403, reason).listFiles(namePattern: 'ssv1.'),
          throwsA(refused(false)),
        );
      });
    }

    test('a 500 is not a refusal', () async {
      await expectLater(
        driveAnswering(500, 'backendError').listFiles(namePattern: 'ssv1.'),
        throwsA(refused(false)),
      );
    });

    test('having no session here is not a refusal', () async {
      // The scheduled-backup isolate has no Google session on a healthy
      // account, so this error must not ask the diver to sign in again.
      await expectLater(
        GoogleDriveStorageProvider().createFolder('backups'),
        throwsA(refused(false)),
      );
    });
  });

  group('Dropbox', () {
    DropboxApiClient client(MockClient mock) => DropboxApiClient(
      getAccessToken: () async => 'token',
      onAccessTokenRejected: () {},
      httpClient: mock,
      wait: (_) async {},
    );

    test('a second 401 is a refusal', () async {
      await expectLater(
        client(
          MockClient((_) async => http.Response('expired', 401)),
        ).getMetadata('/f.json'),
        throwsA(refused(true)),
      );
    });

    test('a repeated 429 is not a refusal', () async {
      await expectLater(
        client(
          MockClient((_) async => http.Response('slow down', 429)),
        ).getMetadata('/f.json'),
        throwsA(refused(false)),
      );
    });

    group('refresh token', () {
      late DropboxAuthStore store;

      setUp(() async {
        store = DropboxAuthStore(storage: InMemoryKeychain());
        await store.save(DropboxAuthData(refreshToken: 'rt'));
      });

      DropboxAuthManager manager(MockClient mock) =>
          DropboxAuthManager(store: store, appKey: 'key', httpClient: mock);

      test('a 400 from the token endpoint is a refusal', () async {
        await expectLater(
          manager(
            MockClient(
              (_) async =>
                  http.Response(jsonEncode({'error': 'invalid_grant'}), 400),
            ),
          ).getAccessToken(),
          throwsA(refused(true)),
        );
      });

      test('a 401 from the token endpoint is a refusal', () async {
        await expectLater(
          manager(
            MockClient((_) async => http.Response('invalid_client', 401)),
          ).getAccessToken(),
          throwsA(refused(true)),
        );
      });

      test('a 429 from the token endpoint is not a refusal', () async {
        await expectLater(
          manager(
            MockClient((_) async => http.Response('slow down', 429)),
          ).getAccessToken(),
          throwsA(refused(false)),
        );
      });

      test('a 500 from the token endpoint is not a refusal', () async {
        await expectLater(
          manager(
            MockClient((_) async => http.Response('down', 500)),
          ).getAccessToken(),
          throwsA(refused(false)),
        );
      });
    });
  });

  group('S3', () {
    S3ApiClient clientReturning(int status, String code) => S3ApiClient(
      S3Config(
        endpoint: 'http://nas.local:9000',
        bucket: 'dive-sync',
        accessKeyId: 'ak',
        secretAccessKey: 'sk',
      ),
      httpClient: MockClient(
        (_) async => http.Response(
          '<Error><Code>$code</Code><Message>m</Message></Error>',
          status,
        ),
      ),
      now: () => DateTime.utc(2026, 6, 9, 12),
      retryDelay: Duration.zero,
    );

    Future<void> put(S3ApiClient c) => c.putObject('k', Uint8List(1));

    for (final code in ['AccessDenied', 'SignatureDoesNotMatch']) {
      test('a 403 $code is a refusal', () async {
        await expectLater(
          put(clientReturning(403, code)),
          throwsA(refused(true)),
        );
      });
    }

    test('a skewed clock is not a refusal', () async {
      await expectLater(
        put(clientReturning(403, 'RequestTimeTooSkewed')),
        throwsA(refused(false)),
      );
    });

    test('a bad signature region is not a refusal', () async {
      await expectLater(
        put(clientReturning(403, 'AuthorizationHeaderMalformed')),
        throwsA(refused(false)),
      );
    });

    test('a 500 is not a refusal', () async {
      await expectLater(
        put(clientReturning(500, 'InternalError')),
        throwsA(refused(false)),
      );
    });
  });

  group('WebDAV', () {
    test('unauthorized and forbidden are refusals', () {
      for (final code in [
        WebDavErrorCode.unauthorized,
        WebDavErrorCode.forbidden,
      ]) {
        expect(WebDavException('x', code: code), refused(true));
      }
    });

    test('nothing else is', () {
      for (final code in WebDavErrorCode.values.where(
        (c) =>
            c != WebDavErrorCode.unauthorized && c != WebDavErrorCode.forbidden,
      )) {
        expect(WebDavException('x', code: code), refused(false));
      }
    });
  });

  group('Git', () {
    test('unauthorized and forbidden are refusals', () {
      for (final code in [GitErrorCode.unauthorized, GitErrorCode.forbidden]) {
        expect(GitException('x', code: code), refused(true));
      }
    });

    test('nothing else is, including a rate limit', () {
      for (final code in GitErrorCode.values.where(
        (c) => c != GitErrorCode.unauthorized && c != GitErrorCode.forbidden,
      )) {
        expect(GitException('x', code: code), refused(false));
      }
    });
  });
}
