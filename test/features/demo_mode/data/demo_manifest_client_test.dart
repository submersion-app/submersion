import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/demo_mode/data/demo_manifest_client.dart';

String manifest(List<int> schemas) => jsonEncode({
  'formatVersion': 1,
  'packages': [
    for (final s in schemas)
      {
        'schemaVersion': s,
        'url': 'https://example.com/s$s.zip',
        'sha256': 'b' * 64,
        'size': 10,
        'generatedAt': '2026-10-20T00:00:00.000Z',
      },
  ],
});

void main() {
  DemoManifestClient clientReturning(
    Future<http.Response> Function(http.Request) handler, {
    Duration timeout = const Duration(seconds: 8),
  }) => DemoManifestClient(client: MockClient(handler), timeout: timeout);

  test('the default manifest url is the demo-data release asset', () {
    expect(
      kDemoManifestUrl,
      'https://github.com/submersion-app/submersion/releases/download/demo-data/demo-manifest.json',
    );
  });

  test('fetchBest returns the matching package on 200', () async {
    Uri? asked;
    final client = clientReturning((r) async {
      asked = r.url;
      return http.Response(manifest([300, 318]), 200);
    });

    final best = await client.fetchBest(318);

    expect(best!.schemaVersion, 318);
    expect(asked.toString(), kDemoManifestUrl);
  });

  group('fetchBest returns null', () {
    test('on 404', () async {
      final client = clientReturning((_) async => http.Response('nope', 404));
      expect(await client.fetchBest(318), isNull);
    });

    test('on timeout', () async {
      final client = clientReturning((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response(manifest([318]), 200);
      }, timeout: const Duration(milliseconds: 20));
      expect(await client.fetchBest(318), isNull);
    });

    test('on malformed JSON', () async {
      final client = clientReturning((_) async => http.Response('{', 200));
      expect(await client.fetchBest(318), isNull);
    });

    test('when only newer schemas exist', () async {
      final client = clientReturning(
        (_) async => http.Response(manifest([400]), 200),
      );
      expect(await client.fetchBest(318), isNull);
    });

    test('when the request throws', () async {
      final client = clientReturning(
        (_) async => throw http.ClientException('offline'),
      );
      expect(await client.fetchBest(318), isNull);
    });
  });
}
