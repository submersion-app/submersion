import 'dart:io';

import 'package:path/path.dart' as p;

/// A throwaway self-signed certificate for 127.0.0.1, generated with
/// openssl at test time so no private key is ever committed.
class SelfSignedTls {
  SelfSignedTls._(this.certPem, this.keyPem);

  final String certPem;
  final String keyPem;

  static Future<SelfSignedTls> generate() async {
    final dir = await Directory.systemTemp.createTemp('self_signed_tls');
    try {
      final key = p.join(dir.path, 'key.pem');
      final cert = p.join(dir.path, 'cert.pem');
      final result = await Process.run('openssl', [
        'req',
        '-x509',
        '-newkey',
        'rsa:2048',
        '-nodes',
        '-keyout',
        key,
        '-out',
        cert,
        '-days',
        '2',
        '-subj',
        '/CN=localhost',
        '-addext',
        'subjectAltName=IP:127.0.0.1,DNS:localhost',
      ]);
      if (result.exitCode != 0) {
        throw StateError(
          'openssl could not make a test certificate: ${result.stderr}',
        );
      }
      return SelfSignedTls._(
        await File(cert).readAsString(),
        await File(key).readAsString(),
      );
    } finally {
      await dir.delete(recursive: true);
    }
  }

  SecurityContext serverContext() => SecurityContext()
    ..useCertificateChainBytes(certPem.codeUnits)
    ..usePrivateKeyBytes(keyPem.codeUnits);

  /// An HTTPS server on loopback answering 'ok'.
  Future<HttpServer> serve() async {
    final server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      serverContext(),
    );
    server.listen(
      (r) => r.response
        ..write('ok')
        ..close(),
    );
    return server;
  }
}
