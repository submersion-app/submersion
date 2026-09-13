import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/log_redactor.dart';

void main() {
  group('redactSecrets', () {
    test('leaves an ordinary message untouched', () {
      const message =
          'Imported 12 dives from Shearwater Perdix | error: '
          'FormatException: bad header (tokenCount: 5, Tokens: 3)';
      expect(redactSecrets(message), message);
    });

    test('redacts OAuth tokens in a query string', () {
      final out = redactSecrets(
        'GET https://example.com/cb?access_token=ya29.abc-DEF_123&state=ok',
      );
      expect(out, isNot(contains('ya29.abc-DEF_123')));
      expect(out, contains('access_token=[REDACTED]'));
      expect(out, contains('state=ok'));
    });

    test('redacts an OAuth authorization code in a redirect URL', () {
      final out = redactSecrets(
        'redirect failed: http://localhost:8765/?code=4/0AbCdEf&scope=drive',
      );
      expect(out, isNot(contains('4/0AbCdEf')));
      expect(out, contains('scope=drive'));
    });

    test('does not treat an ordinary "code" word as a secret', () {
      const message = 'libdc returned status code 7 (code=DC_STATUS_IO)';
      expect(redactSecrets(message), message);
    });

    test('redacts token and secret fields in a JSON body', () {
      final out = redactSecrets(
        'Token refresh failed | error: {"error":"invalid_grant",'
        '"refresh_token": "1//0gXyZ", "client_secret":"GOCSPX-s3cr3t"}',
      );
      expect(out, isNot(contains('1//0gXyZ')));
      expect(out, isNot(contains('GOCSPX-s3cr3t')));
      expect(out, contains('invalid_grant'));
    });

    test('redacts token fields in a Dart Map toString', () {
      final out = redactSecrets(
        'Response: {accessToken: abc.def.ghi, expiresIn: 3600}',
      );
      expect(out, isNot(contains('abc.def.ghi')));
      expect(out, contains('expiresIn: 3600'));
    });

    test('redacts passwords', () {
      final out = redactSecrets('WebDAV login failed: password=hunter2 user=x');
      expect(out, isNot(contains('hunter2')));
      expect(out, contains('user=x'));
    });

    test('redacts a Bearer token and a whole Authorization header', () {
      final bearer = redactSecrets('headers: Bearer eyJhbGciOi.payload.sig');
      expect(bearer, isNot(contains('eyJhbGciOi.payload.sig')));

      final basic = redactSecrets('Authorization: Basic dXNlcjpwYXNz, Host: x');
      expect(basic, isNot(contains('dXNlcjpwYXNz')));
      expect(basic, contains('Host: x'));
    });

    test('redacts S3 presigned URL signature and credential params', () {
      final out = redactSecrets(
        'PUT https://bucket.s3.amazonaws.com/db.sqlite?'
        'X-Amz-Algorithm=AWS4-HMAC-SHA256'
        '&X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20260912%2Fus-east-1'
        '&X-Amz-Security-Token=FwoGZXIvYXdzEJr'
        '&X-Amz-Signature=fe5f80f77d5fa3beca038a248ff027',
      );
      expect(out, isNot(contains('AKIAIOSFODNN7EXAMPLE')));
      expect(out, isNot(contains('FwoGZXIvYXdzEJr')));
      expect(out, isNot(contains('fe5f80f77d5fa3beca038a248ff027')));
      expect(out, contains('X-Amz-Algorithm=AWS4-HMAC-SHA256'));
    });

    test('redacts a bare AWS access key id and a secret access key', () {
      final out = redactSecrets(
        'S3 config: AKIAIOSFODNN7EXAMPLE, '
        'secretAccessKey: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
      );
      expect(out, isNot(contains('AKIAIOSFODNN7EXAMPLE')));
      expect(out, isNot(contains('wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY')));
    });

    test('redacts the SQLCipher key a SqliteException echoes', () {
      const hexKey =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final attach = redactSecrets(
        'Enable encryption failed | error: SqliteException(13): database or '
        'disk is full, Causing statement: ATTACH DATABASE \'/tmp/e.db\' AS '
        'encrypted KEY "x\'$hexKey\'"',
      );
      expect(attach, isNot(contains(hexKey)));
      expect(attach, contains('database or disk is full'));

      final pragma = redactSecrets('PRAGMA key = "x\'$hexKey\'";');
      expect(pragma, isNot(contains(hexKey)));
    });

    test('redacts signed-link parameters in user-supplied media URLs', () {
      final out = redactSecrets(
        'Network scan: https://cdn.example.com/a.jpg?sig=AbC123&se=2026 '
        'https://dl.dropbox.com/s/x/b.jpg?rlkey=zz9&dl=1 '
        'https://storage.googleapis.com/b/c.jpg?X-Goog-Signature=f00d&'
        'X-Goog-Credential=svc%40p.iam '
        'https://feed.example.com/m.json?key=k3y&api_key=k4y '
        'https://www.googleapis.com/upload?upload_id=ADPycd '
        'https://sso.garmin.com/p?ticket=ST-0123456789-abc',
      );
      for (final secret in [
        'AbC123',
        'zz9',
        'f00d',
        'svc%40p.iam',
        'k3y',
        'k4y',
        'ADPycd',
        'ST-0123456789-abc',
      ]) {
        expect(out, isNot(contains(secret)), reason: secret);
      }
      expect(out, contains('se=2026'));
      expect(out, contains('dl=1'));
    });

    test('redacts bare Google, Dropbox and JWT token shapes', () {
      final out = redactSecrets(
        'tokens: ya29.a0AfB_byC-xyz 1//0gAbCdEfGhIjKlMnOpQrStUv '
        'GOCSPX-AbCdEf123 sl.BAbCdEfGhIjKlMnOpQrStUvWx '
        'eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxIn0.c2ln',
      );
      for (final secret in [
        'ya29.a0AfB_byC-xyz',
        '1//0gAbCdEfGhIjKlMnOpQrStUv',
        'GOCSPX-AbCdEf123',
        'sl.BAbCdEfGhIjKlMnOpQrStUvWx',
        'eyJzdWIiOiIxIn0',
      ]) {
        expect(out, isNot(contains(secret)), reason: secret);
      }
    });

    test('redacts vendor authorization headers and session keys', () {
      final out = redactSecrets(
        'Suunto request failed: STTAuthorization: abcdef123456, '
        '{sessionKey: s3ss10n}',
      );
      expect(out, isNot(contains('abcdef123456')));
      expect(out, isNot(contains('s3ss10n')));
    });

    test('leaves messages that only name a secret untouched', () {
      const configMessage =
          'Data-protection keychain unavailable and the Desktop OAuth client '
          'is incomplete (needs --dart-define=GOOGLE_DRIVE_CLIENT_SECRET); '
          'Google Drive sign-in is disabled in this build';
      expect(redactSecrets(configMessage), configMessage);

      const challenge =
          'HTTP 401, www-authenticate: Bearer realm="api", error="invalid"';
      expect(redactSecrets(challenge), challenge);
    });

    test('never reaches across a newline into the next log line', () {
      const next = '[2026-09-12T09:00:01.000] [APP] [ERROR] next, line';
      for (final first in [
        '[2026-09-12T09:00:00.000] [APP] [WARN] no refresh_token:',
        '[2026-09-12T09:00:00.000] [APP] [WARN] header authorization:',
      ]) {
        final out = redactSecrets('$first\n$next');
        expect(out.split('\n').last, next, reason: first);
      }
    });

    test('redacts a quoted value with spaces whole', () {
      final out = redactSecrets(
        '{"password": "correct horse battery staple", "user": "x"}',
      );
      expect(out, isNot(contains('horse')));
      expect(out, isNot(contains('staple')));
      expect(out, contains('"user": "x"'));
    });

    test('redacts every cookie in a Cookie header', () {
      final out = redactSecrets('Cookie: a=1; sessionid=secret123; b=2');
      expect(out, isNot(contains('secret123')));
    });

    test('redacts a SigV4 Authorization header signature', () {
      const signature =
          'fe5f80f77d5fa3beca038a248ff027d0445342fe2855ddc963176630326f1024';
      final out = redactSecrets(
        'S3 PUT failed: Authorization: AWS4-HMAC-SHA256 '
        'Credential=AKIAIOSFODNN7EXAMPLE/20260912/us-east-1/s3/aws4_request, '
        'SignedHeaders=host;x-amz-date, Signature=$signature',
      );
      expect(out, isNot(contains(signature)));
      expect(out, isNot(contains('AKIAIOSFODNN7EXAMPLE')));
    });

    test('redacts credentials embedded in a URL', () {
      final out = redactSecrets(
        'WebDAV PROPFIND https://diver:hunter2@dav.example.com/remote.php',
      );
      expect(out, isNot(contains('hunter2')));
      expect(out, contains('dav.example.com/remote.php'));
    });
  });
}
