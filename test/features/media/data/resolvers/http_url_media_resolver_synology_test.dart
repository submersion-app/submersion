import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/media/data/resolvers/http_url_media_resolver.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/data/services/network_url_resolver.dart';
import 'package:submersion/features/media/data/synology/synology_share_link.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

class _StubCreds implements NetworkCredentialsService {
  @override
  Future<Map<String, String>?> headersFor(Uri uri) async => null;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

final _link = SynologyShareLink.tryParseShareLink(
  Uri.parse('https://nas.example.com:5001/mo/sharing/code1'),
)!;

MediaItem _item(String url) => MediaItem(
  id: 'm1',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.manifestEntry,
  url: url,
  takenAt: DateTime.utc(2024, 1, 1),
  createdAt: DateTime.utc(2024, 1, 1),
  updatedAt: DateTime.utc(2024, 1, 1),
);

HttpUrlMediaResolver _resolver({
  http.Client? client,
  Future<Map<String, String>?> Function(Uri uri)? headersFor,
}) => HttpUrlMediaResolver(
  sourceType: MediaSourceType.manifestEntry,
  networkUrlResolver: NetworkUrlResolver(
    client: client ?? MockClient((_) async => http.Response('', 200)),
    credentials: _StubCreds(),
  ),
  headersFor: headersFor,
);

void main() {
  final original = _link.originalUri(id: 5, cacheKey: '5_9').toString();

  test('resolve passes the lookup headers to the image', () async {
    final data = await _resolver(
      headersFor: (_) async => {'Cookie': 'sharing_sid=s'},
    ).resolve(_item(original));
    expect(data, isA<NetworkData>());
    expect((data as NetworkData).headers, {'Cookie': 'sharing_sid=s'});
    expect(data.url.toString(), original);
  });

  test('a failing header lookup still resolves, without headers', () async {
    final data = await _resolver(
      headersFor: (_) async => throw StateError('keychain'),
    ).resolve(_item('https://example.com/a.jpg'));
    expect((data as NetworkData).headers, isEmpty);
  });

  test('a Synology thumbnail is the m rendition, not the original', () async {
    final data = await _resolver().resolveThumbnail(
      _item(original),
      target: const Size(200, 200),
    );
    expect(
      (data as NetworkData).url,
      _link.thumbnailUri(id: 5, cacheKey: '5_9', size: SynologyThumbnailSize.m),
    );
  });

  test('other thumbnails keep the item URL', () async {
    final data = await _resolver().resolveThumbnail(
      _item('https://example.com/a.jpg'),
      target: const Size(200, 200),
    );
    expect((data as NetworkData).url, Uri.parse('https://example.com/a.jpg'));
  });

  test('a JSON answer for a Synology URL is no proof of life', () async {
    final resolver = _resolver(
      client: MockClient(
        (_) async => http.Response(
          '{"success":false,"error":{"code":804}}',
          200,
          headers: {'content-type': 'application/json; charset="UTF-8"'},
        ),
      ),
    );
    expect(await resolver.verify(_item(original)), VerifyResult.transientError);
  });

  test('media bytes for a Synology URL are available', () async {
    final resolver = _resolver(
      client: MockClient(
        (_) async => http.Response.bytes(
          [0xff],
          206,
          headers: {'content-type': 'image/jpeg'},
        ),
      ),
    );
    expect(await resolver.verify(_item(original)), VerifyResult.available);
  });
}
