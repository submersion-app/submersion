import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_tls.dart';

void main() {
  final pin = 'ab' * 32;
  WebDavCertificateDetails cert({
    String sha = '',
    String host = 'nas.local',
    int port = 5006,
  }) => WebDavCertificateDetails(
    host: host,
    port: port,
    sha256: sha.isEmpty ? pin : sha,
    subject: 'CN=nas.local',
    issuer: 'CN=nas.local',
    startValidity: DateTime.utc(2026),
    endValidity: DateTime.utc(2027),
  );
  WebDavConfig config({String? pinned}) => WebDavConfig(
    serverUrl: 'https://nas.local:5006',
    username: 'u',
    password: 'p',
    pinnedCertSha256: pinned,
  );

  test('fingerprints format as colon-separated uppercase pairs', () {
    expect(formatFingerprint('0a1bff'), '0A:1B:FF');
    expect(certificateSha256Hex([1, 2, 3]).length, 64);
  });

  test('a pin accepts only the same cert on the same host and port', () {
    final recorder = CertificateTrustRecorder.forConfig(config(pinned: pin));
    expect(recorder.evaluate(cert()), isTrue);
    expect(recorder.takeRejected(), isNull);
    expect(recorder.evaluate(cert(sha: 'cd' * 32)), isFalse);
    expect(recorder.takeRejected()!.sha256, 'cd' * 32);
    expect(recorder.evaluate(cert(host: 'evil.example')), isFalse);
    expect(recorder.evaluate(cert(port: 443)), isFalse);
  });

  test('with no pin every untrusted cert is rejected and recorded once', () {
    final recorder = CertificateTrustRecorder.forConfig(config());
    expect(recorder.evaluate(cert()), isFalse);
    expect(recorder.takeRejected(), isNotNull);
    expect(recorder.takeRejected(), isNull);
  });

  test('untrusted exception flags a changed certificate', () {
    final first = WebDavUntrustedCertificateException(cert());
    final changed = WebDavUntrustedCertificateException(
      cert(sha: 'cd' * 32),
      pinnedSha256: pin,
    );
    expect(first.pinMismatch, isFalse);
    expect(first.message, contains('nas.local'));
    expect(changed.pinMismatch, isTrue);
    expect(changed.code, WebDavErrorCode.untrustedCertificate);
  });

  test('certificate errors say where to review the certificate', () {
    expect(
      WebDavUntrustedCertificateException(cert()).message,
      contains('WebDAV settings'),
    );
    expect(
      WebDavUntrustedCertificateException(cert(), pinnedSha256: pin).message,
      contains('WebDAV settings'),
    );
  });
}
