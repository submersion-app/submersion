import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/media/data/services/network_url_resolver.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';

class _StubCreds implements NetworkCredentialsService {
  _StubCreds(this.headers);
  final Map<String, String>? headers;
  @override
  Future<Map<String, String>?> headersFor(Uri uri) async => headers;
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  group('NetworkUrlResolver.fetch', () {
    test('returns BytesData on 200', () async {
      final body = utf8.encode('hello');
      final client = MockClient(
        (req) async => http.Response.bytes(
          body,
          200,
          headers: {'content-type': 'image/jpeg'},
        ),
      );
      final resolver = NetworkUrlResolver(
        client: client,
        credentials: _StubCreds(null),
      );
      final result = await resolver.fetch(
        Uri.parse('https://example.com/a.jpg'),
      );
      expect(result, isA<NetworkBytesOk>());
      final ok = result as NetworkBytesOk;
      expect(ok.bytes, body);
      expect(ok.contentType, 'image/jpeg');
    });

    test('returns Unauthenticated on 401', () async {
      final client = MockClient((req) async => http.Response('', 401));
      final resolver = NetworkUrlResolver(
        client: client,
        credentials: _StubCreds(null),
      );
      expect(
        await resolver.fetch(Uri.parse('https://example.com/a.jpg')),
        isA<NetworkBytesUnauthenticated>(),
      );
    });

    test('attaches credentials when host is known', () async {
      Map<String, String>? seenHeaders;
      final client = MockClient((req) async {
        seenHeaders = req.headers;
        return http.Response.bytes(const [1, 2, 3], 200);
      });
      final resolver = NetworkUrlResolver(
        client: client,
        credentials: _StubCreds({'Authorization': 'Bearer x'}),
      );
      await resolver.fetch(Uri.parse('https://example.com/a.jpg'));
      expect(seenHeaders!['Authorization'], 'Bearer x');
    });

    test('records finalUrl when redirect chain ends elsewhere', () async {
      // 3 redirects then 200.
      var hops = 0;
      final client = MockClient((req) async {
        hops += 1;
        if (hops < 3) {
          return http.Response(
            '',
            302,
            headers: {'location': 'https://cdn.example.com/a.jpg'},
          );
        }
        return http.Response.bytes(const [1], 200);
      });
      final resolver = NetworkUrlResolver(
        client: client,
        credentials: _StubCreds(null),
      );
      final result = await resolver.fetch(
        Uri.parse('https://example.com/a.jpg'),
      );
      final ok = result as NetworkBytesOk;
      expect(ok.finalUrl, 'https://cdn.example.com/a.jpg');
    });

    test('aborts after 5 redirects', () async {
      final client = MockClient(
        (req) async => http.Response(
          '',
          302,
          headers: {'location': 'https://example.com/loop'},
        ),
      );
      final resolver = NetworkUrlResolver(
        client: client,
        credentials: _StubCreds(null),
      );
      expect(
        await resolver.fetch(Uri.parse('https://example.com/start')),
        isA<NetworkBytesError>(),
      );
    });

    test('returns NetworkError on >= 500', () async {
      final client = MockClient((req) async => http.Response('', 503));
      final resolver = NetworkUrlResolver(
        client: client,
        credentials: _StubCreds(null),
      );
      expect(
        await resolver.fetch(Uri.parse('https://example.com/a.jpg')),
        isA<NetworkBytesError>(),
      );
    });
  });
}
