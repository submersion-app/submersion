import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/network_url_resolver.dart';
import 'package:submersion/features/media/data/services/url_metadata_extractor.dart';
import 'package:submersion/features/media/domain/entities/extracted_metadata.dart';

class _StubResolver implements NetworkUrlResolver {
  _StubResolver(this._results);
  final List<NetworkBytesResult> _results;
  int _i = 0;
  @override
  Future<NetworkBytesResult> fetch(
    Uri uri, {
    Map<String, String>? extraHeaders,
  }) async => _results[_i++];
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('range request fills metadata when EXIF present', () async {
    final extractor = UrlMetadataExtractor(
      resolver: _StubResolver([
        NetworkBytesOk(
          bytes: Uint8List.fromList(const [/* fake jpeg with exif */]),
          contentType: 'image/jpeg',
          finalUrl: 'https://example.com/a.jpg',
        ),
      ]),
      exifExtract: (bytes) async =>
          const ExtractedMetadata(takenAt: null, width: 4032, height: 3024),
    );
    final result = await extractor.extract(
      Uri.parse('https://example.com/a.jpg'),
    );
    expect(result.width, 4032);
    expect(result.finalUrl, 'https://example.com/a.jpg');
  });

  test('falls back to full GET when range request returns 416', () async {
    final extractor = UrlMetadataExtractor(
      resolver: _StubResolver([
        const NetworkBytesError('HTTP 416'),
        NetworkBytesOk(
          bytes: Uint8List.fromList(const []),
          contentType: 'image/jpeg',
          finalUrl: 'https://example.com/a.jpg',
        ),
      ]),
      exifExtract: (bytes) async => const ExtractedMetadata(),
    );
    final result = await extractor.extract(
      Uri.parse('https://example.com/a.jpg'),
    );
    expect(result.finalUrl, 'https://example.com/a.jpg');
  });

  test('returns failure when both attempts fail', () async {
    final extractor = UrlMetadataExtractor(
      resolver: _StubResolver([
        const NetworkBytesError('boom'),
        const NetworkBytesError('boom'),
      ]),
      exifExtract: (bytes) async => const ExtractedMetadata(),
    );
    final result = await extractor.extract(
      Uri.parse('https://example.com/a.jpg'),
    );
    expect(result.failure, isNotNull);
  });

  test('flags videos for full download', () async {
    final extractor = UrlMetadataExtractor(
      resolver: _StubResolver([
        NetworkBytesOk(
          bytes: Uint8List.fromList(const []),
          contentType: 'video/mp4',
          finalUrl: 'https://example.com/a.mp4',
        ),
      ]),
      exifExtract: (bytes) async => const ExtractedMetadata(),
    );
    final result = await extractor.extract(
      Uri.parse('https://example.com/a.mp4'),
    );
    expect(result.requiresFullDownload, isTrue);
  });

  test('parses Last-Modified as UTC wall-clock', () async {
    final extractor = UrlMetadataExtractor(
      resolver: _StubResolver([
        NetworkBytesOk(
          bytes: Uint8List.fromList(const []),
          contentType: 'image/jpeg',
          finalUrl: 'https://example.com/a.jpg',
          lastModified: DateTime.utc(2024, 4, 12, 14, 32, 0),
        ),
      ]),
      exifExtract: (bytes) async => const ExtractedMetadata(),
    );
    final result = await extractor.extract(
      Uri.parse('https://example.com/a.jpg'),
    );
    expect(result.takenAt, DateTime.utc(2024, 4, 12, 14, 32, 0));
  });
}
