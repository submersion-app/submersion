import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'blocked_network.dart';

class _FakeClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Matcher _refusalOf(String target) => isA<StateError>().having(
  (error) => error.message,
  'message',
  startsWith('A test reached the network: $target.'),
);

void main() {
  group('isLoopbackHost', () {
    for (final host in [
      'localhost',
      'LOCALHOST',
      'localhost.',
      '127.0.0.1',
      '127.1.2.3',
      '::1',
      '[::1]',
      'api.localhost',
      '::ffff:127.0.0.1',
      '[::ffff:127.0.0.1]',
    ]) {
      test('$host is this machine', () {
        expect(isLoopbackHost(host), isTrue);
      });
    }

    test('loopback InternetAddresses are this machine', () {
      expect(isLoopbackHost(InternetAddress.loopbackIPv4), isTrue);
      expect(isLoopbackHost(InternetAddress.loopbackIPv6), isTrue);
    });

    test('a Unix domain socket is this machine', () {
      expect(
        isLoopbackHost(
          InternetAddress('/run/test.sock', type: InternetAddressType.unix),
        ),
        isTrue,
      );
    });

    for (final host in [
      'example.com',
      'fonts.gstatic.com',
      'localhost.example.com',
      'notlocalhost',
      '::ffff:8.8.8.8',
      '8.8.8.8',
      '10.0.0.1',
      '',
    ]) {
      test("'$host' is not", () {
        expect(isLoopbackHost(host), isFalse);
      });
    }

    test('anything that is not a host is not', () {
      expect(isLoopbackHost(null), isFalse);
      expect(isLoopbackHost(42), isFalse);
    });
  });

  group('the refusal check', () {
    Future<void> swallowedRequest(String url) =>
        HttpOverrides.runWithHttpOverrides(() async {
          final client = HttpClient();
          try {
            await client.getUrl(Uri.parse(url));
          } catch (_) {
            // Code under test that catches every error, as some services do.
          } finally {
            client.close(force: true);
          }
        }, blockedNetworkHttpOverrides);

    test(
      'fails when a refusal was caught before it could fail the test',
      () async {
        resetNetworkRefusals();
        await swallowedRequest('https://example.com/swallowed');

        expect(
          expectNoNetworkRefusals,
          throwsA(
            isA<TestFailure>().having(
              (failure) => failure.message,
              'message',
              contains('https://example.com/swallowed'),
            ),
          ),
        );
      },
    );

    test(
      'before a test, fails on a refusal caught since the last test',
      () async {
        resetNetworkRefusals();
        await swallowedRequest('https://example.com/in-set-up-all');

        expect(
          expectNoNetworkRefusalsBeforeTest,
          throwsA(
            isA<TestFailure>().having(
              (failure) => failure.message,
              'message',
              allOf(
                contains('https://example.com/in-set-up-all'),
                contains('setUpAll'),
              ),
            ),
          ),
        );
        expect(expectNoNetworkRefusals, returnsNormally);
      },
    );

    test('passes when nothing was refused', () {
      resetNetworkRefusals();

      expect(expectNoNetworkRefusals, returnsNormally);
    });

    test('passes when the test said it expects refusals', () async {
      resetNetworkRefusals();
      expectNetworkRefusals();
      await swallowedRequest('https://example.com/on-purpose');

      expect(expectNoNetworkRefusals, returnsNormally);
    });

    test('starts clean after each check', () async {
      resetNetworkRefusals();
      await swallowedRequest('https://example.com/once');
      expect(expectNoNetworkRefusals, throwsA(isA<TestFailure>()));

      expect(expectNoNetworkRefusals, returnsNormally);
    });
  });

  group('BlockedNetworkHttpOverrides', () {
    // These tests are refused on purpose.
    setUp(expectNetworkRefusals);

    test('a request to a public host fails with its URL', () async {
      final error = await HttpOverrides.runWithHttpOverrides(() async {
        final client = HttpClient();
        try {
          await client.getUrl(Uri.parse('https://example.com/fonts.ttf'));
          return null;
        } catch (caught) {
          return caught;
        } finally {
          client.close(force: true);
        }
      }, blockedNetworkHttpOverrides);

      expect(error, _refusalOf('https://example.com/fonts.ttf'));
    });

    test('a loopback HttpServer still answers', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) {
        request.response
          ..write('ok')
          ..close();
      });

      final body = await HttpOverrides.runWithHttpOverrides(() async {
        final client = HttpClient();
        try {
          final request = await client.getUrl(
            Uri.parse('http://127.0.0.1:${server.port}/'),
          );
          final response = await request.close();
          return await response.transform(utf8.decoder).join();
        } finally {
          client.close(force: true);
        }
      }, blockedNetworkHttpOverrides);

      expect(body, 'ok');
    });

    test('HttpOverrides.runZoned inside it still wins', () {
      final client = HttpOverrides.runWithHttpOverrides(
        () => HttpOverrides.runZoned(
          HttpClient.new,
          createHttpClient: (_) => _FakeClient(),
        ),
        blockedNetworkHttpOverrides,
      );

      expect(client, isA<_FakeClient>());
    });
  });

  group('BlockedNetworkIOOverrides', () {
    setUp(expectNetworkRefusals);

    test('Socket.connect to a public host fails with host and port', () async {
      final error = await IOOverrides.runWithIOOverrides(
        () => Socket.connect('example.com', 443).then<Object?>((socket) {
          socket.destroy();
          return null;
        }, onError: (Object caught) => caught),
        blockedNetworkIOOverrides,
      );

      expect(error, _refusalOf('example.com:443'));
    });

    test('Socket.startConnect to a public host fails too', () async {
      final error = await IOOverrides.runWithIOOverrides(
        () => Socket.startConnect('8.8.8.8', 53).then<Object?>((task) {
          task.cancel();
          return null;
        }, onError: (Object caught) => caught),
        blockedNetworkIOOverrides,
      );

      expect(error, _refusalOf('8.8.8.8:53'));
    });

    test('Socket.connect to a loopback server still connects', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((socket) => socket.destroy());

      final socket = await IOOverrides.runWithIOOverrides(
        () => Socket.connect(InternetAddress.loopbackIPv4, server.port),
        blockedNetworkIOOverrides,
      );
      final connectedTo = socket.remoteAddress;
      socket.destroy();

      expect(connectedTo.isLoopback, isTrue);
    });
  });
}
