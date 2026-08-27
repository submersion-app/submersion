import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/services/manifest_fetch_service.dart';

class _FakeCreds implements ManifestCredentialsLookup {
  _FakeCreds(this.byHost);

  final Map<String, Map<String, String>> byHost;

  @override
  Future<Map<String, String>> headersFor(Uri uri) async =>
      byHost[uri.host] ?? const {};
}

void main() {
  group('ManifestFetchService', () {
    test('JSON success returns parsed entries', () async {
      final client = MockClient(
        (req) async => http.Response(
          '{"version":1,"title":"t","items":[{"url":"https://x/a"}]}',
          200,
          headers: {
            'content-type': 'application/json',
            'etag': 'W/"abc"',
            'last-modified': 'Sat, 12 Apr 2024 14:00:00 GMT',
          },
        ),
      );
      final svc = ManifestFetchService(
        client: client,
        credentials: _FakeCreds(const {}),
      );
      final result = await svc.fetch(Uri.parse('https://example.com/m.json'));
      expect(result, isA<ManifestFetchSuccess>());
      final ok = result as ManifestFetchSuccess;
      expect(ok.parsed.format, ManifestFormat.json);
      expect(ok.parsed.entries, hasLength(1));
      expect(ok.etag, 'W/"abc"');
      expect(ok.lastModified, 'Sat, 12 Apr 2024 14:00:00 GMT');
    });

    test('304 returns NotModified with timestamps', () async {
      final client = MockClient((req) async {
        expect(req.headers['if-none-match'], '"abc"');
        expect(
          req.headers['if-modified-since'],
          'Sat, 12 Apr 2024 14:00:00 GMT',
        );
        return http.Response('', 304);
      });
      final svc = ManifestFetchService(
        client: client,
        credentials: _FakeCreds(const {}),
      );
      final result = await svc.fetch(
        Uri.parse('https://example.com/m.json'),
        ifNoneMatch: '"abc"',
        ifModifiedSince: 'Sat, 12 Apr 2024 14:00:00 GMT',
      );
      expect(result, isA<ManifestFetchNotModified>());
    });

    test('non-2xx returns Failure', () async {
      final client = MockClient((req) async => http.Response('nope', 500));
      final svc = ManifestFetchService(
        client: client,
        credentials: _FakeCreds(const {}),
      );
      final result = await svc.fetch(Uri.parse('https://x/m'));
      expect(result, isA<ManifestFetchFailure>());
      expect((result as ManifestFetchFailure).statusCode, 500);
    });

    test('format override skips sniffing', () async {
      // Body looks like JSON but we force CSV — parser will throw.
      final client = MockClient(
        (req) async => http.Response(
          '{"version":1,"items":[]}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      final svc = ManifestFetchService(
        client: client,
        credentials: _FakeCreds(const {}),
      );
      final result = await svc.fetch(
        Uri.parse('https://x/m'),
        formatOverride: ManifestFormat.csv,
      );
      expect(result, isA<ManifestFetchFailure>());
      expect((result as ManifestFetchFailure).message, contains('url'));
    });

    test('credentials headers are sent on the GET', () async {
      var sawAuth = false;
      final client = MockClient((req) async {
        sawAuth = req.headers['authorization'] == 'Basic Zm9vOmJhcg==';
        return http.Response(
          '{"version":1,"items":[]}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final svc = ManifestFetchService(
        client: client,
        credentials: _FakeCreds({
          'example.com': {'authorization': 'Basic Zm9vOmJhcg=='},
        }),
      );
      await svc.fetch(Uri.parse('https://example.com/m.json'));
      expect(sawAuth, isTrue);
    });

    test('401 surfaces as Unauthorized failure for sign-in flow', () async {
      final client = MockClient((req) async => http.Response('', 401));
      final svc = ManifestFetchService(
        client: client,
        credentials: _FakeCreds(const {}),
      );
      final result = await svc.fetch(Uri.parse('https://x/m'));
      expect(result, isA<ManifestFetchFailure>());
      expect((result as ManifestFetchFailure).statusCode, 401);
      expect(result.unauthorized, isTrue);
    });
  });
}
