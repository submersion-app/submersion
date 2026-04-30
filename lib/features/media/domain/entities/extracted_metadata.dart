import 'package:equatable/equatable.dart';

/// Metadata extracted from raw media bytes (EXIF for images, container
/// headers for video) by [UrlMetadataExtractor] / [ExifExtractor].
///
/// Distinct from [MediaSourceMetadata] which is the resolver-facing value
/// object stored on `MediaItem`. [ExtractedMetadata] is the narrower
/// "what we got out of the bytes" payload — fields are nullable when the
/// source did not include them. Wall-clock-UTC convention applies to
/// [takenAt] (see `ExifExtractor` for the parsing side).
class ExtractedMetadata extends Equatable {
  final DateTime? takenAt;
  final int? width;
  final int? height;
  final double? lat;
  final double? lon;

  const ExtractedMetadata({
    this.takenAt,
    this.width,
    this.height,
    this.lat,
    this.lon,
  });

  @override
  List<Object?> get props => [takenAt, width, height, lat, lon];
}
