import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';
import 'package:submersion/features/media/data/services/manifest_fetch_service.dart';
import 'package:submersion/features/media/data/synology/synology_album_source.dart';
import 'package:submersion/features/media/data/synology/synology_share_link.dart';

class _NoCreds implements ManifestCredentialsLookup {
  @override
  Future<Map<String, String>> headersFor(Uri uri) async => const {};
}

class _FakeAlbumSource implements SynologyAlbumSource {
  final List<SynologyShareLink> fetched = [];

  @override
  Future<ManifestFetchOutcome> fetch(SynologyShareLink link) async {
    fetched.add(link);
    return const ManifestFetchSuccess(
      parsed: ManifestParseResult(format: ManifestFormat.json, entries: []),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('a share link is read through the album source', () async {
    var httpCalls = 0;
    final albums = _FakeAlbumSource();
    final service = ManifestFetchService(
      client: MockClient((_) async {
        httpCalls++;
        return http.Response('', 500);
      }),
      credentials: _NoCreds(),
      synologyAlbums: albums,
    );

    final outcome = await service.fetch(
      Uri.parse('https://nas.example.com:5001/mo/sharing/code1'),
      // A stored subscription carries `json`; it must not reach the parser.
      formatOverride: ManifestFormat.json,
      ifNoneMatch: 'W/"x"',
    );

    expect(outcome, isA<ManifestFetchSuccess>());
    expect(albums.fetched.single.code, 'code1');
    expect(httpCalls, 0);
  });

  test('other URLs keep the feed path', () async {
    final albums = _FakeAlbumSource();
    final service = ManifestFetchService(
      client: MockClient(
        (_) async => http.Response(
          '{"version":1,"items":[]}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
      credentials: _NoCreds(),
      synologyAlbums: albums,
    );

    final outcome = await service.fetch(
      Uri.parse('https://example.com/manifest.json'),
    );

    expect(outcome, isA<ManifestFetchSuccess>());
    expect(albums.fetched, isEmpty);
  });
}
