import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/synology/synology_share_link.dart';

void main() {
  group('SynologyShareLink.tryParseShareLink', () {
    test('parses a share link with a port', () {
      final link = SynologyShareLink.tryParseShareLink(
        Uri.parse('https://nas.example.com:5001/mo/sharing/AbC12_-x'),
      );
      expect(link, isNotNull);
      expect(link!.origin, Uri.parse('https://nas.example.com:5001'));
      expect(link.code, 'AbC12_-x');
      expect(link.pathPrefix, '');
    });

    test('parses a share link without a port and with a trailing slash', () {
      final link = SynologyShareLink.tryParseShareLink(
        Uri.parse('https://nas.example.com/mo/sharing/code1/'),
      );
      expect(link!.origin, Uri.parse('https://nas.example.com'));
      expect(link.code, 'code1');
    });

    test('keeps the /photo prefix used behind a reverse proxy', () {
      final link = SynologyShareLink.tryParseShareLink(
        Uri.parse('https://nas.example.com/photo/mo/sharing/code1'),
      );
      expect(link!.pathPrefix, '/photo');
      expect(
        link.apiUri,
        Uri.parse('https://nas.example.com/photo/mo/sharing/webapi/entry.cgi'),
      );
    });

    test('ignores a fragment', () {
      final link = SynologyShareLink.tryParseShareLink(
        Uri.parse('https://nas.example.com/mo/sharing/code1#/item/5'),
      );
      expect(link!.code, 'code1');
    });

    test('rejects plain http: the password would travel in clear text', () {
      expect(
        SynologyShareLink.tryParseShareLink(
          Uri.parse('http://nas.example.com/mo/sharing/code1'),
        ),
        isNull,
      );
    });

    test('rejects other paths', () {
      for (final raw in [
        'https://nas.example.com/',
        'https://nas.example.com/mo/sharing/',
        'https://nas.example.com/mo/sharing/a/b',
        'https://nas.example.com/mo/sharing/webapi/entry.cgi',
        'https://nas.example.com/manifest.json',
        'https://nas.example.com/mo/sharing/bad%20code',
      ]) {
        expect(
          SynologyShareLink.tryParseShareLink(Uri.parse(raw)),
          isNull,
          reason: raw,
        );
      }
    });
  });

  group('built URLs', () {
    final link = SynologyShareLink.tryParseShareLink(
      Uri.parse('https://nas.example.com:5001/mo/sharing/code1'),
    )!;

    test('original download URL carries id and cache_key', () {
      final uri = link.originalUri(id: 42, cacheKey: '42_100');
      expect(uri.path, '/mo/sharing/webapi/entry.cgi');
      expect(uri.queryParameters['api'], 'SYNO.Foto.Download');
      expect(uri.queryParameters['method'], 'download');
      expect(uri.queryParameters['item_id'], '[42]');
      expect(uri.queryParameters['download_type'], 'source');
      expect(uri.queryParameters['passphrase'], 'code1');
      expect(uri.queryParameters['_sharing_id'], 'code1');
      expect(uri.queryParameters['id'], '42');
      expect(uri.queryParameters['cache_key'], '42_100');
    });

    test('thumbnail URL', () {
      final uri = link.thumbnailUri(
        id: 42,
        cacheKey: '42_100',
        size: SynologyThumbnailSize.m,
      );
      expect(uri.queryParameters['api'], 'SYNO.Foto.Thumbnail');
      expect(uri.queryParameters['id'], '42');
      expect(uri.queryParameters['cache_key'], '42_100');
      expect(uri.queryParameters['size'], 'm');
      expect(uri.queryParameters['type'], 'unit');
      expect(uri.queryParameters['_sharing_id'], 'code1');
    });

    test('thumbnailFor derives a thumbnail from a stored original URL', () {
      final original = link.originalUri(id: 42, cacheKey: '42_100');
      final thumb = SynologyShareLink.thumbnailFor(
        original,
        SynologyThumbnailSize.sm,
      );
      expect(
        thumb,
        link.thumbnailUri(
          id: 42,
          cacheKey: '42_100',
          size: SynologyThumbnailSize.sm,
        ),
      );
    });

    test('thumbnailFor re-sizes a stored thumbnail URL', () {
      final xl = link.thumbnailUri(
        id: 42,
        cacheKey: '42_100',
        size: SynologyThumbnailSize.xl,
      );
      final m = SynologyShareLink.thumbnailFor(xl, SynologyThumbnailSize.m);
      expect(m!.queryParameters['size'], 'm');
    });

    test('thumbnailFor returns null for foreign URLs', () {
      expect(
        SynologyShareLink.thumbnailFor(
          Uri.parse('https://example.com/a.jpg'),
          SynologyThumbnailSize.m,
        ),
        isNull,
      );
    });
  });

  group('SynologyShareLink.tryParseAny', () {
    test('recovers the share from an API URL it built', () {
      final link = SynologyShareLink.tryParseShareLink(
        Uri.parse('https://nas.example.com:5001/photo/mo/sharing/code1'),
      )!;
      final parsed = SynologyShareLink.tryParseAny(
        link.originalUri(id: 1, cacheKey: '1_1'),
      );
      expect(parsed!.key, link.key);
      expect(parsed.pathPrefix, '/photo');
    });

    test('accepts the share link itself', () {
      final parsed = SynologyShareLink.tryParseAny(
        Uri.parse('https://nas.example.com/mo/sharing/code1'),
      );
      expect(parsed!.code, 'code1');
    });

    test('rejects an API URL without a share id', () {
      expect(
        SynologyShareLink.tryParseAny(
          Uri.parse(
            'https://nas.example.com/mo/sharing/webapi/entry.cgi?api=x',
          ),
        ),
        isNull,
      );
    });

    test('rejects other hosts and paths', () {
      expect(
        SynologyShareLink.tryParseAny(Uri.parse('https://example.com/a.jpg')),
        isNull,
      );
    });
  });

  test('key distinguishes shares and hosts', () {
    final a = SynologyShareLink.tryParseShareLink(
      Uri.parse('https://nas.example.com/mo/sharing/a'),
    )!;
    final b = SynologyShareLink.tryParseShareLink(
      Uri.parse('https://nas.example.com/mo/sharing/b'),
    )!;
    final c = SynologyShareLink.tryParseShareLink(
      Uri.parse('https://other.example.com/mo/sharing/a'),
    )!;
    expect({a.key, b.key, c.key}, hasLength(3));
  });
}
