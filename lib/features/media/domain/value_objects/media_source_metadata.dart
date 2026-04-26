import 'package:equatable/equatable.dart';

/// Metadata extracted from a media source at link time.
///
/// Populated by `MediaSourceResolver.extractMetadata()` and stored on the
/// `MediaItem` row by the calling repository. All fields except [mimeType]
/// are nullable to accommodate sources that don't expose them.
class MediaSourceMetadata extends Equatable {
  final DateTime? takenAt;
  final double? latitude;
  final double? longitude;
  final int? width;
  final int? height;
  final int? durationSeconds;
  final String mimeType;

  const MediaSourceMetadata({
    this.takenAt,
    this.latitude,
    this.longitude,
    this.width,
    this.height,
    this.durationSeconds,
    required this.mimeType,
  });

  @override
  List<Object?> get props => [
    takenAt,
    latitude,
    longitude,
    width,
    height,
    durationSeconds,
    mimeType,
  ];
}
