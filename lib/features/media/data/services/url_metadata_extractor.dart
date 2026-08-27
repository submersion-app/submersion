import 'dart:typed_data';
import 'package:submersion/features/media/data/services/network_url_resolver.dart';
import 'package:submersion/features/media/domain/entities/extracted_metadata.dart';

typedef ExifExtractFn = Future<ExtractedMetadata> Function(Uint8List bytes);

class UrlExtractionResult {
  const UrlExtractionResult({
    required this.url,
    required this.finalUrl,
    this.takenAt,
    this.width,
    this.height,
    this.lat,
    this.lon,
    this.contentType,
    this.requiresFullDownload = false,
    this.failure,
  });

  final String url;
  final String finalUrl;
  final DateTime? takenAt;
  final int? width;
  final int? height;
  final double? lat;
  final double? lon;
  final String? contentType;
  final bool requiresFullDownload;
  final String? failure;
}

class UrlMetadataExtractor {
  UrlMetadataExtractor({
    required NetworkUrlResolver resolver,
    required ExifExtractFn exifExtract,
  }) : _resolver = resolver,
       _exif = exifExtract;

  final NetworkUrlResolver _resolver;
  final ExifExtractFn _exif;

  Future<UrlExtractionResult> extract(Uri uri) async {
    final rangeAttempt = await _resolver.fetch(
      uri,
      extraHeaders: {'Range': 'bytes=0-65535'},
    );
    if (rangeAttempt is NetworkBytesUnauthenticated) {
      return UrlExtractionResult(
        url: uri.toString(),
        finalUrl: uri.toString(),
        failure: 'unauthenticated',
      );
    }
    if (rangeAttempt is NetworkBytesOk) {
      return _fromBytes(uri, rangeAttempt);
    }
    final fullAttempt = await _resolver.fetch(uri);
    if (fullAttempt is NetworkBytesOk) {
      return _fromBytes(uri, fullAttempt);
    }
    if (fullAttempt is NetworkBytesUnauthenticated) {
      return UrlExtractionResult(
        url: uri.toString(),
        finalUrl: uri.toString(),
        failure: 'unauthenticated',
      );
    }
    return UrlExtractionResult(
      url: uri.toString(),
      finalUrl: uri.toString(),
      failure: (fullAttempt as NetworkBytesError).message,
    );
  }

  Future<UrlExtractionResult> _fromBytes(Uri uri, NetworkBytesOk ok) async {
    final isVideo = ok.contentType?.startsWith('video/') ?? false;
    if (isVideo) {
      return UrlExtractionResult(
        url: uri.toString(),
        finalUrl: ok.finalUrl,
        contentType: ok.contentType,
        requiresFullDownload: true,
        takenAt: ok.lastModified,
      );
    }
    final exif = await _exif(ok.bytes);
    return UrlExtractionResult(
      url: uri.toString(),
      finalUrl: ok.finalUrl,
      contentType: ok.contentType,
      width: exif.width,
      height: exif.height,
      takenAt: exif.takenAt ?? ok.lastModified,
      lat: exif.lat,
      lon: exif.lon,
    );
  }
}
