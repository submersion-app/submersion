import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_tls.dart';

import '../../../../helpers/fake_webdav_server.dart';

WebDavConfig _config({String password = 'secret'}) => WebDavConfig(
  serverUrl: 'https://dav.test/dav',
  username: 'alice',
  password: password,
);

class _Recording extends http.BaseClient {
  _Recording(this.inner);
  final http.Client inner;
  final seen = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    seen.add(request);
    return inner.send(request);
  }
}

class _HandshakeFailingClient extends http.BaseClient {
  _HandshakeFailingClient(this.recorder, this.details);
  final CertificateTrustRecorder recorder;
  final WebDavCertificateDetails details;
  int sends = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sends++;
    recorder.evaluate(details);
    throw const HandshakeException('CERTIFICATE_VERIFY_FAILED');
  }
}

/// Takes the first body chunk, holds the stream paused for a while, then
/// drains the rest: a real socket under a slow link behaves like this.
class _PausingConsumer extends http.BaseClient {
  _PausingConsumer(this.whilePaused);
  final void Function() whilePaused;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = StreamIterator(request.finalize());
    await body.moveNext();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    whilePaused();
    while (await body.moveNext()) {}
    return http.StreamedResponse(const Stream.empty(), 201);
  }
}

void main() {
  late FakeWebDavServer server;
  late WebDavClient client;
  late Directory tmp;

  setUp(() async {
    server = FakeWebDavServer();
    client = WebDavClient(
      _config(),
      httpClient: server.client,
      backoff: (_) => Duration.zero,
    );
    tmp = await Directory.systemTemp.createTemp('webdav_client_test');
  });

  tearDown(() async {
    client.close();
    await tmp.delete(recursive: true);
  });

  test('uriFor percent-encodes segments under the DAV root', () {
    expect(
      client.uriFor('Submersion Media/a b.json').toString(),
      'https://dav.test/dav/Submersion%20Media/a%20b.json',
    );
    expect(client.uriFor('x', collection: true).path, '/dav/x/');
  });

  test(
    'round-trips bytes with Basic auth and creates missing parents on 409',
    () async {
      await client.putBytes('Submersion/deep/a b.json', utf8.encode('hello'));
      expect(
        server.files['/dav/Submersion/deep/a b.json'],
        utf8.encode('hello'),
      );
      expect(
        utf8.decode(await client.getBytes('Submersion/deep/a b.json')),
        'hello',
      );
      expect(server.captured.every((r) => !r.followRedirects), isTrue);
    },
  );

  test(
    'stat and listChildren decode names and work with absolute hrefs',
    () async {
      server
        ..absoluteHrefs = true
        ..seedFile('/dav/Submersion Media/x y.json', [1, 2, 3])
        ..seedCollection('/dav/Submersion Media/sub');
      final children = await client.listChildren('Submersion Media');
      expect(children.map((e) => e.name), unorderedEquals(['x y.json', 'sub']));
      final file = children.firstWhere((e) => !e.isCollection);
      expect(file.path, 'Submersion Media/x y.json');
      expect(file.sizeBytes, 3);
      expect(await client.stat('Submersion Media/missing.json'), isNull);
      expect((await client.stat(''))!.isCollection, isTrue);
    },
  );

  test(
    'a server that echoes the DAV root in another case still lists it',
    () async {
      server
        ..seedFile('/dav/Submersion/a.json', [1, 2])
        ..hrefPath = ((p) => p.replaceFirst('/dav', '/DAV'));
      final children = await client.listChildren('Submersion');
      expect(children.map((e) => e.path), ['Submersion/a.json']);
      expect((await client.stat('Submersion/a.json'))?.sizeBytes, 2);
    },
  );

  test('a missing DAV root is a notFound naming the address', () async {
    server.collections.remove('/dav');
    await expectLater(
      client.stat(''),
      throwsA(
        isA<WebDavException>()
            .having((e) => e.code, 'code', WebDavErrorCode.notFound)
            .having((e) => e.message, 'message', contains('Check the address')),
      ),
    );
  });

  test('ensureCollection creates nested levels once and caches them', () async {
    await client.ensureCollection('a/b/c');
    expect(
      server.collections,
      containsAll(['/dav/a', '/dav/a/b', '/dav/a/b/c']),
    );
    final before = server.count('MKCOL');
    await client.ensureCollection('a/b/c');
    expect(server.count('MKCOL'), before);
  });

  test('putFile streams with Content-Length and reports progress', () async {
    // MockClient re-buffers every request, so record the ORIGINAL request
    // to see that it was streamed with an explicit length.
    final recording = _Recording(server.client);
    final streaming = WebDavClient(
      _config(),
      httpClient: recording,
      backoff: (_) => Duration.zero,
    );
    addTearDown(streaming.close);
    final source = File(p.join(tmp.path, 'big.bin'));
    await source.writeAsBytes(List<int>.generate(300000, (i) => i % 251));
    int? last;
    await streaming.putFile(
      'Submersion/big.bin',
      source,
      onProgress: (sent, total) => last = sent,
    );
    final put = recording.seen.lastWhere((r) => r.method == 'PUT');
    // Not a buffered http.Request: the body is streamed from the file.
    expect(put, isNot(isA<http.Request>()));
    expect(put.contentLength, 300000);
    expect(server.files['/dav/Submersion/big.bin']!.length, 300000);
    expect(last, 300000);
  });

  test(
    'getToFile writes the file and leaves nothing behind on failure',
    () async {
      server.seedFile('/dav/Submersion/a.bin', [9, 8, 7]);
      final dest = File(p.join(tmp.path, 'a.bin'));
      await client.getToFile('Submersion/a.bin', dest);
      expect(await dest.readAsBytes(), [9, 8, 7]);

      final missing = File(p.join(tmp.path, 'missing.bin'));
      await expectLater(
        client.getToFile('Submersion/nope.bin', missing),
        throwsA(isA<WebDavException>()),
      );
      expect(await missing.exists(), isFalse);
    },
  );

  test('delete of a missing path succeeds', () async {
    await client.delete('Submersion/nope.json');
  });

  test('401 asks for an app password and never prints the password', () async {
    final bad = WebDavClient(
      _config(password: 'wrong'),
      httpClient: server.client,
      backoff: (_) => Duration.zero,
    );
    addTearDown(bad.close);
    try {
      await bad.getBytes('x');
      fail('expected a WebDavException');
    } on WebDavException catch (e) {
      expect(e.code, WebDavErrorCode.unauthorized);
      expect(e.displayMessage, contains('HTTP 401'));
      expect(e.toString(), isNot(contains('wrong')));
    }
  });

  test('a redirect is reported with its target, not followed', () async {
    server
      ..forcedStatuses.add(301)
      ..forcedHeaders = {'location': 'https://dav.test/dav2/'};
    await expectLater(
      client.stat(''),
      throwsA(
        isA<WebDavException>()
            .having((e) => e.code, 'code', WebDavErrorCode.redirected)
            .having(
              (e) => e.message,
              'message',
              contains('https://dav.test/dav2/'),
            ),
      ),
    );
  });

  test('413 names the refused size', () async {
    server.maxPutBytes = 10;
    await expectLater(
      client.putBytes('Submersion/a.bin', Uint8List(2 * 1024 * 1024)),
      throwsA(
        isA<WebDavException>()
            .having((e) => e.code, 'code', WebDavErrorCode.tooLarge)
            .having((e) => e.message, 'message', contains('2 MB')),
      ),
    );
  });

  test('5xx and transport errors retry; 507 does not', () async {
    server.forcedStatuses.addAll([503, 503]);
    await client.stat('');
    expect(server.count('PROPFIND'), 3);

    server.forcedStatuses.add(507);
    await expectLater(
      client.putBytes('x', Uint8List(1)),
      throwsA(isA<WebDavException>()),
    );
    expect(server.count('PUT'), 1);

    server
      ..throwNext = const SocketException('down')
      ..throwCount = 6;
    await expectLater(
      client.stat(''),
      throwsA(
        isA<WebDavException>().having(
          (e) => e.code,
          'code',
          WebDavErrorCode.unreachable,
        ),
      ),
    );
  });

  test('a PROPFIND answered with HTML is not a WebDAV endpoint', () async {
    final html = WebDavClient(
      _config(),
      httpClient: MockClient(
        (_) async => http.Response('<html>login</html>', 200),
      ),
      backoff: (_) => Duration.zero,
    );
    addTearDown(html.close);
    await expectLater(
      html.stat(''),
      throwsA(
        isA<WebDavException>().having(
          (e) => e.code,
          'code',
          WebDavErrorCode.notWebDav,
        ),
      ),
    );
  });

  test(
    'an untrusted certificate surfaces its details and is not retried',
    () async {
      final config = _config();
      final recorder = CertificateTrustRecorder.forConfig(config);
      final failing = _HandshakeFailingClient(
        recorder,
        WebDavCertificateDetails(
          host: 'dav.test',
          port: 443,
          sha256: 'ab' * 32,
          subject: 'CN=dav.test',
          issuer: 'CN=dav.test',
          startValidity: DateTime.utc(2026),
          endValidity: DateTime.utc(2027),
        ),
      );
      final pinned = WebDavClient(
        config,
        httpClient: failing,
        trustRecorder: recorder,
        backoff: (_) => Duration.zero,
      );
      addTearDown(pinned.close);
      await expectLater(
        pinned.stat(''),
        throwsA(
          isA<WebDavUntrustedCertificateException>().having(
            (e) => e.certificate.sha256,
            'sha',
            'ab' * 32,
          ),
        ),
      );
      expect(failing.sends, 1);
    },
  );

  test(
    'putFile reads the file only as fast as the transport takes it',
    () async {
      final source = File(p.join(tmp.path, 'video.bin'));
      const total = 8 * 1024 * 1024;
      await source.writeAsBytes(Uint8List(total));
      var sent = 0;
      int? sentWhilePaused;
      final slow = WebDavClient(
        _config(),
        httpClient: _PausingConsumer(() => sentWhilePaused = sent),
        backoff: (_) => Duration.zero,
      );
      addTearDown(slow.close);
      await slow.putFile(
        'Submersion/video.bin',
        source,
        onProgress: (s, _) => sent = s,
      );
      expect(
        sentWhilePaused,
        lessThan(total ~/ 2),
        reason: 'the whole file was read while the transport sat paused',
      );
      expect(sent, total);
    },
  );

  test('upload deadlines scale with the body size', () {
    expect(WebDavClient.deadlineFor('GET', null), const Duration(seconds: 30));
    expect(
      WebDavClient.deadlineFor('PUT', 1024 * 1024),
      const Duration(minutes: 10),
    );
    expect(
      WebDavClient.deadlineFor('PUT', 1 << 30),
      greaterThan(const Duration(hours: 2)),
    );
  });

  test('a large error page is read only as far as the excerpt needs', () async {
    var pulled = 0;
    Stream<List<int>> largePage() async* {
      for (var i = 0; i < 2000; i++) {
        pulled++;
        yield List<int>.filled(4096, 0x41);
      }
    }

    final client = WebDavClient(
      _config(),
      httpClient: MockClient.streaming(
        (request, body) async => http.StreamedResponse(largePage(), 418),
      ),
      backoff: (_) => Duration.zero,
    );
    addTearDown(client.close);
    await expectLater(
      client.getBytes('x'),
      throwsA(
        isA<WebDavException>().having((e) => e.statusCode, 'status', 418),
      ),
    );
    expect(pulled, lessThan(10), reason: 'the whole 8 MB page was read');
  });
}
