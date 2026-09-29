import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'blocked_network.dart';
import 'fake_hosts.dart';

Future<({int status, String body})> _getWithDartIo(String url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set('User-Agent', 'fake-hosts-test');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return (status: response.statusCode, body: body);
  } finally {
    client.close(force: true);
  }
}

void main() {
  group('a declared fake host', () {
    test('answers dart:io requests over https as offline by default', () async {
      serveFakeHost('nominatim.openstreetmap.org');

      final result = await _getWithDartIo(
        'https://nominatim.openstreetmap.org/reverse?lat=1&lon=2',
      );

      expect(result.status, 503);
      expect(fakeHostRequests.single.method, 'GET');
      expect(
        fakeHostRequests.single.url.toString(),
        'https://nominatim.openstreetmap.org/reverse?lat=1&lon=2',
      );
    });

    test('answers package:http with the JSON it was given', () async {
      serveFakeHost(
        'api.open-meteo.com',
        FakeResponse.json({
          'elevation': [42.0],
        }),
      );

      final response = await http.get(
        Uri.parse('https://api.open-meteo.com/v1/elevation?latitude=1'),
      );

      expect(response.statusCode, 200);
      expect(jsonDecode(response.body), {
        'elevation': [42.0],
      });
    });

    test('sees the body and method of a request it answers', () async {
      serveFakeHostWith(
        'api.example.test',
        (request) => FakeResponse(201, body: 'got ${request.body}'),
      );

      final response = await http.post(
        Uri.parse('https://api.example.test/items'),
        body: 'hello',
      );

      expect(response.statusCode, 201);
      expect(response.body, 'got hello');
      expect(fakeHostRequests.single.method, 'POST');
      expect(fakeHostRequests.single.body, 'hello');
    });

    testWidgets('answers inside a widget test without real async', (
      tester,
    ) async {
      serveFakeHost('tile.openstreetmap.org', const FakeResponse(404));

      final response = await http.get(
        Uri.parse('https://tile.openstreetmap.org/1/2/3.png'),
      );

      expect(response.statusCode, 404);
    });

    test('is forgotten when the fake hosts are reset', () async {
      expectNetworkRefusals();
      serveFakeHost('api.example.test');
      resetFakeHosts();

      await expectLater(
        _getWithDartIo('https://api.example.test/'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('an undeclared host', () {
    setUp(expectNetworkRefusals);

    test('is still refused while other hosts are faked', () async {
      serveFakeHost('api.example.test');

      await expectLater(
        _getWithDartIo('https://example.com/'),
        throwsA(isA<StateError>()),
      );
    });

    test('cannot be reached through a proxy the caller chose', () async {
      final client = HttpClient()..findProxy = (_) => 'PROXY example.com:8080';
      addTearDown(() => client.close(force: true));

      // The request is for this machine, but the proxy is not: connecting to
      // the proxy is a socket to a public host, which is refused.
      await expectLater(
        client.getUrl(Uri.parse('http://127.0.0.1:9/')),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('example.com:8080'),
          ),
        ),
      );
    });

    test('is refused even when the caller replaces findProxy', () async {
      final client = HttpClient()..findProxy = (_) => 'DIRECT';
      addTearDown(() => client.close(force: true));

      await expectLater(
        client.getUrl(Uri.parse('https://example.com/')),
        throwsA(isA<StateError>()),
      );
    });
  });

  test('a loopback server still answers through the routing client', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response
        ..write('local')
        ..close();
    });

    final result = await _getWithDartIo('http://127.0.0.1:${server.port}/');

    expect(result.body, 'local');
  });
}
