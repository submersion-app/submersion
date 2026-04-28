import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/media/data/resolvers/manifest_entry_resolver.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/data/services/network_url_resolver.dart';
import 'package:submersion/features/media/data/services/url_metadata_extractor.dart';
import 'package:submersion/features/media/domain/entities/extracted_metadata.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

class _StubCreds implements NetworkCredentialsService {
  @override
  Future<Map<String, String>?> headersFor(Uri uri) async => null;
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

ManifestEntryResolver _makeResolver({
  http.Client? client,
  ExifExtractFn? exif,
}) {
  final c = client ?? MockClient((_) async => http.Response.bytes([], 200));
  final resolver = NetworkUrlResolver(client: c, credentials: _StubCreds());
  final extractor = UrlMetadataExtractor(
    resolver: resolver,
    exifExtract: exif ?? (_) async => const ExtractedMetadata(),
  );
  return ManifestEntryResolver(
    networkUrlResolver: resolver,
    urlMetadataExtractor: extractor,
  );
}

MediaItem _manifestItem({String? url}) => MediaItem(
  id: 'manifest-1',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.manifestEntry,
  url: url,
  takenAt: DateTime.utc(2024, 1, 1),
  createdAt: DateTime.utc(2024, 1, 1),
  updatedAt: DateTime.utc(2024, 1, 1),
);

void main() {
  group('ManifestEntryResolver', () {
    test('reports MediaSourceType.manifestEntry', () {
      final r = _makeResolver();
      expect(r.sourceType, MediaSourceType.manifestEntry);
    });

    group('canResolveOnThisDevice', () {
      test('returns true when the item has a URL', () {
        final r = _makeResolver();
        expect(
          r.canResolveOnThisDevice(
            _manifestItem(url: 'https://example.com/a.jpg'),
          ),
          isTrue,
        );
      });

      test('returns false when the item has no URL', () {
        final r = _makeResolver();
        expect(r.canResolveOnThisDevice(_manifestItem()), isFalse);
      });
    });

    group('resolve', () {
      test('returns NetworkData for a well-formed URL', () async {
        final r = _makeResolver();
        final data = await r.resolve(
          _manifestItem(url: 'https://example.com/a.jpg'),
        );
        expect(data, isA<NetworkData>());
        expect(
          (data as NetworkData).url.toString(),
          'https://example.com/a.jpg',
        );
      });

      test('returns Unavailable.notFound when URL is missing', () async {
        final r = _makeResolver();
        final data = await r.resolve(_manifestItem());
        expect(data, isA<UnavailableData>());
        expect((data as UnavailableData).kind, UnavailableKind.notFound);
      });

      test('resolveThumbnail delegates to resolve', () async {
        final r = _makeResolver();
        final data = await r.resolveThumbnail(
          _manifestItem(url: 'https://example.com/a.jpg'),
          target: const Size(120, 120),
        );
        expect(data, isA<NetworkData>());
      });
    });

    group('extractMetadata', () {
      test('returns metadata from a 200 response', () async {
        final body = Uint8List.fromList([1, 2, 3]);
        final client = MockClient(
          (req) async => http.Response.bytes(
            body,
            200,
            headers: {'content-type': 'image/jpeg'},
          ),
        );
        final r = _makeResolver(
          client: client,
          exif: (_) async => ExtractedMetadata(
            takenAt: DateTime.utc(2024, 5, 1, 12),
            width: 800,
            height: 600,
            lat: 12.5,
            lon: -34.25,
          ),
        );
        final meta = await r.extractMetadata(
          _manifestItem(url: 'https://example.com/a.jpg'),
        );
        expect(meta, isNotNull);
        expect(meta!.mimeType, 'image/jpeg');
        expect(meta.width, 800);
        expect(meta.height, 600);
        expect(meta.latitude, 12.5);
        expect(meta.longitude, -34.25);
        expect(meta.takenAt, DateTime.utc(2024, 5, 1, 12));
      });

      test('falls back to a generic mime type when none is reported', () async {
        final client = MockClient(
          (req) async => http.Response.bytes([1, 2, 3], 200),
        );
        final r = _makeResolver(client: client);
        final meta = await r.extractMetadata(
          _manifestItem(url: 'https://example.com/a.jpg'),
        );
        expect(meta, isNotNull);
        expect(meta!.mimeType, 'application/octet-stream');
      });

      test('returns null on extractor failure', () async {
        final client = MockClient((req) async => http.Response('', 500));
        final r = _makeResolver(client: client);
        final meta = await r.extractMetadata(
          _manifestItem(url: 'https://example.com/a.jpg'),
        );
        expect(meta, isNull);
      });

      test('returns null when URL is missing', () async {
        final r = _makeResolver();
        expect(await r.extractMetadata(_manifestItem()), isNull);
      });
    });

    group('verify', () {
      test('returns available on 200', () async {
        final client = MockClient((req) async => http.Response.bytes([0], 200));
        final r = _makeResolver(client: client);
        final v = await r.verify(
          _manifestItem(url: 'https://example.com/a.jpg'),
        );
        expect(v, VerifyResult.available);
      });

      test('returns unauthenticated on 401', () async {
        final client = MockClient((req) async => http.Response('', 401));
        final r = _makeResolver(client: client);
        final v = await r.verify(
          _manifestItem(url: 'https://example.com/a.jpg'),
        );
        expect(v, VerifyResult.unauthenticated);
      });

      test('returns notFound on 404', () async {
        final client = MockClient((req) async => http.Response('', 404));
        final r = _makeResolver(client: client);
        final v = await r.verify(
          _manifestItem(url: 'https://example.com/a.jpg'),
        );
        expect(v, VerifyResult.notFound);
      });

      test('returns notFound when URL is missing', () async {
        final r = _makeResolver();
        expect(await r.verify(_manifestItem()), VerifyResult.notFound);
      });
    });
  });
}
