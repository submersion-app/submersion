import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:submersion/core/platform/web/cors_diagnoser.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';

/// A browser hides the status of a request another origin refused, so the
/// connect step classifies the failure's shape (issue #4121).
void main() {
  const origin = 'https://dives.example.com';
  final publicS3 = Uri.parse('https://s3.eu-central-1.amazonaws.com');
  final opaque = http.ClientException('XMLHttpRequest error.', publicS3);

  CorsDiagnosis run(
    Object error, {
    Uri? endpoint,
    bool isWebDav = false,
    bool failedOnWrite = false,
    bool optionsSucceeded = false,
  }) => diagnose(
    error: error,
    endpoint: endpoint ?? publicS3,
    origin: origin,
    isWebDav: isWebDav,
    failedOnWrite: failedOnWrite,
    optionsSucceeded: optionsSucceeded,
  );

  group('verdicts', () {
    test('an opaque failure on the first request: the store blocks us', () {
      final d = run(opaque);
      expect(d.verdict, CorsVerdict.blockedByCors);
      expect(d.kind, StoreKind.awsS3);
      expect(d.origin, origin);
      expect(d.ruleTemplate, contains(origin));
    });

    test('an opaque failure wrapped by the S3 client is still opaque', () {
      final wrapped = CloudStorageException(
        'Could not reach S3 endpoint s3.eu-central-1.amazonaws.com',
        opaque,
      );
      expect(run(wrapped).verdict, CorsVerdict.blockedByCors);
      expect(
        run(http.ClientException('Failed to fetch')).verdict,
        CorsVerdict.blockedByCors,
      );
    });

    test('opaque after a successful OPTIONS: the method is not allowed '
        '(a WebDAV server that serves GET but not PROPFIND)', () {
      final d = run(
        opaque,
        endpoint: Uri.parse('https://cloud.example.org/remote.php/dav'),
        isWebDav: true,
        optionsSucceeded: true,
      );
      expect(d.verdict, CorsVerdict.methodBlockedByCors);
      expect(d.kind, StoreKind.nextcloud);
      expect(d.ruleTemplate, contains('Access-Control-Allow-Methods'));
      expect(d.ruleTemplate, contains('PROPFIND'));
    });

    test('opaque only on a write: reads are allowed, writes are not', () {
      final d = run(opaque, failedOnWrite: true);
      expect(d.verdict, CorsVerdict.writeBlockedByCors);
      expect(d.ruleTemplate, contains('PUT'));
      expect(d.ruleTemplate, contains('DELETE'));
    });

    test('a refused account is forbidden, not a CORS problem', () {
      expect(
        run(const CloudAccessRefusedException('Access denied')).verdict,
        CorsVerdict.forbidden,
      );
      expect(
        run(
          WebDavException('no', code: WebDavErrorCode.forbidden),
          isWebDav: true,
        ).verdict,
        CorsVerdict.forbidden,
      );
    });

    test('a missing bucket or path is not found', () {
      expect(
        run(const CloudStorageException('NoSuchBucket: dive-sync')).verdict,
        CorsVerdict.notFound,
      );
      expect(
        run(const CloudStorageException('S3 returned 404 for list')).verdict,
        CorsVerdict.notFound,
      );
      expect(
        run(
          WebDavException('gone', code: WebDavErrorCode.notFound),
          isWebDav: true,
        ).verdict,
        CorsVerdict.notFound,
      );
    });

    test('opaque to a private HTTPS host: the browser does not trust it', () {
      for (final host in ['192.168.1.20', 'nas.local', 'minio', 'nas.home']) {
        final d = run(opaque, endpoint: Uri.parse('https://$host:9000'));
        expect(d.verdict, CorsVerdict.tlsOrUnreachable, reason: host);
      }
      // Plain HTTP to the same host has no certificate to distrust.
      expect(
        run(opaque, endpoint: Uri.parse('http://nas.local:9000')).verdict,
        CorsVerdict.blockedByCors,
      );
    });

    test('anything else is unknown, with the usual rule to try', () {
      final d = run(StateError('odd'));
      expect(d.verdict, CorsVerdict.unknown);
      expect(d.ruleTemplate, contains(origin));
    });

    test('ok exists for a check that passed', () {
      expect(CorsVerdict.values, contains(CorsVerdict.ok));
    });
  });

  group('detectStoreKind', () {
    test('names the hosted stores by their domains', () {
      expect(detectStoreKind(publicS3, isWebDav: false), StoreKind.awsS3);
      expect(
        detectStoreKind(
          Uri.parse('https://abc123.r2.cloudflarestorage.com'),
          isWebDav: false,
        ),
        StoreKind.cloudflareR2,
      );
      expect(
        detectStoreKind(
          Uri.parse('https://s3.us-west-004.backblazeb2.com'),
          isWebDav: false,
        ),
        StoreKind.backblazeB2,
      );
    });

    test('a MinIO port or name is MinIO, anything else generic S3', () {
      expect(
        detectStoreKind(Uri.parse('http://nas.local:9000'), isWebDav: false),
        StoreKind.minio,
      );
      expect(
        detectStoreKind(
          Uri.parse('https://minio.example.org'),
          isWebDav: false,
        ),
        StoreKind.minio,
      );
      expect(
        detectStoreKind(
          Uri.parse('https://store.example.org'),
          isWebDav: false,
        ),
        StoreKind.genericS3,
      );
    });

    test('Nextcloud by its DAV path, anything else generic WebDAV', () {
      expect(
        detectStoreKind(
          Uri.parse('https://cloud.example.org/remote.php/dav/files/me'),
          isWebDav: true,
        ),
        StoreKind.nextcloud,
      );
      expect(
        detectStoreKind(
          Uri.parse('https://dav.example.org/dives'),
          isWebDav: true,
        ),
        StoreKind.genericWebDav,
      );
    });
  });

  test('WebKit names the same opaque failure differently', () {
    expect(
      isOpaqueBrowserFailure(http.ClientException('TypeError: Load failed')),
      isTrue,
    );
  });

  test('private hosts include IPv6 local ranges and home.arpa', () {
    expect(isPrivateHost('nas.home.arpa'), isTrue);
    expect(isPrivateHost('fd00::10'), isTrue);
    expect(isPrivateHost('fe80::1'), isTrue);
    expect(isPrivateHost('2606:4700::1111'), isFalse);
  });
}
