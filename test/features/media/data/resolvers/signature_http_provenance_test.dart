import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/media/data/resolvers/http_url_media_resolver.dart';
import 'package:submersion/features/media/data/resolvers/signature_resolver.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/data/services/network_url_resolver.dart';
import 'package:submersion/features/media/data/services/url_metadata_extractor.dart';
import 'package:submersion/features/media/domain/entities/extracted_metadata.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

class _StubCreds implements NetworkCredentialsService {
  @override
  Future<Map<String, String>?> headersFor(Uri uri) async => null;
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

HttpUrlMediaResolver _httpResolver(MediaSourceType sourceType) {
  final resolver = NetworkUrlResolver(
    client: MockClient((_) async => http.Response.bytes([], 200)),
    credentials: _StubCreds(),
  );
  return HttpUrlMediaResolver(
    sourceType: sourceType,
    networkUrlResolver: resolver,
    urlMetadataExtractor: UrlMetadataExtractor(
      resolver: resolver,
      exifExtract: (_) async => const ExtractedMetadata(),
    ),
  );
}

MediaItem _signature({Uint8List? imageData, String? filePath}) => MediaItem(
  id: 'sig',
  mediaType: MediaType.instructorSignature,
  sourceType: MediaSourceType.signature,
  imageData: imageData,
  filePath: filePath,
  takenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

MediaItem _urlItem(MediaSourceType sourceType) => MediaItem(
  id: 'u1',
  mediaType: MediaType.photo,
  sourceType: sourceType,
  url: 'https://example.test/reef.jpg',
  takenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  group('SignatureResolver', () {
    test('an inline signature blob is stamped embedded', () async {
      final data = await SignatureResolver().resolve(
        _signature(imageData: Uint8List.fromList(const [1, 2, 3])),
      );

      expect(data, isA<BytesData>());
      expect(data.servedFrom, ServedFrom.embedded);
      expect(data.servedTier, ServedTier.original);
    });

    test('a signature file on disk is also stamped embedded', () async {
      final dir = await Directory.systemTemp.createTemp('sig_prov');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final f = File('${dir.path}/sig.png');
      await f.writeAsBytes(const [1, 2, 3], flush: true);

      final data = await SignatureResolver().resolve(
        _signature(filePath: f.path),
      );

      expect(data, isA<FileData>());
      expect(data.servedFrom, ServedFrom.embedded);
    });

    test('a signature with nothing to read claims no source', () async {
      final data = await SignatureResolver().resolve(_signature());

      expect(data, isA<UnavailableData>());
      expect(data.servedFrom, isNull);
    });
  });

  group('HttpUrlMediaResolver', () {
    test('a networkUrl row is stamped networkUrl', () async {
      final data = await _httpResolver(
        MediaSourceType.networkUrl,
      ).resolve(_urlItem(MediaSourceType.networkUrl));

      expect(data, isA<NetworkData>());
      expect(data.servedFrom, ServedFrom.networkUrl);
      expect(data.servedTier, ServedTier.original);
    });

    test('a manifestEntry row is stamped networkUrl too', () async {
      // ServedFrom records the byte transport, and both source types hand
      // the same HTTP transport to cached_network_image. The distinction
      // between them is link provenance, which lives on MediaItem.sourceType.
      final data = await _httpResolver(
        MediaSourceType.manifestEntry,
      ).resolve(_urlItem(MediaSourceType.manifestEntry));

      expect(data, isA<NetworkData>());
      expect(data.servedFrom, ServedFrom.networkUrl);
    });

    test('a row with no url claims no source', () async {
      final data = await _httpResolver(MediaSourceType.networkUrl).resolve(
        MediaItem(
          id: 'u2',
          mediaType: MediaType.photo,
          sourceType: MediaSourceType.networkUrl,
          takenAt: DateTime.utc(2026),
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );

      expect(data, isA<UnavailableData>());
      expect(data.servedFrom, isNull);
    });
  });
}
