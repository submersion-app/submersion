import 'package:equatable/equatable.dart';

/// One entry parsed from a manifest feed (Atom, RSS, JSON, or CSV).
///
/// Stable identity across polls is provided by [entryKey], which is required
/// and unique per `(subscriptionId, entryKey)` (enforced by the partial unique
/// index `idx_media_subscription_entry`).
///
/// All metadata fields are optional. When present, they are written to the
/// resulting `MediaItem` row directly and EXIF extraction is skipped. When
/// absent, the eager fetch pipeline fills them in from EXIF over HTTP.
class ManifestEntry extends Equatable {
  /// Stable identifier within the manifest. For Atom this is `<id>`, for
  /// RSS `<guid>`, for JSON the `id` field (or `SHA(url + takenAt ?? '')`
  /// fallback), for CSV the `id` column (or the same SHA fallback).
  final String entryKey;

  /// Direct URL to the media bytes (image or video).
  final String url;

  /// When the photo/video was captured. Stored wall-clock-as-UTC.
  final DateTime? takenAt;

  /// Free-form caption / title from the feed.
  final String? caption;

  /// Optional thumbnail URL, used for fast preview before the full fetch
  /// completes.
  final String? thumbnailUrl;

  /// Latitude in decimal degrees.
  final double? latitude;

  /// Longitude in decimal degrees.
  final double? longitude;

  /// Pixel width.
  final int? width;

  /// Pixel height.
  final int? height;

  /// Duration in whole seconds. Set for video entries only.
  final int? durationSeconds;

  /// Media kind hint from the feed: `'photo'` or `'video'`. Optional;
  /// the resolver re-derives from MIME type if absent.
  final String? mediaType;

  /// The publisher states it has supplied everything it knows about this
  /// entry, so the fetch pipeline must not download the bytes to look for
  /// more. Without it, an entry skips extraction only when it carries
  /// `takenAt`, size AND GPS; a source that never has GPS (Synology Photos
  /// shares) would otherwise download every original on the first import.
  final bool metadataComplete;

  /// The original file name, when the source knows it. Named in the import
  /// review and stored as the row's original file name; unlike [caption] it
  /// is not a user-facing caption.
  final String? filename;

  const ManifestEntry({
    required this.entryKey,
    required this.url,
    this.takenAt,
    this.caption,
    this.thumbnailUrl,
    this.latitude,
    this.longitude,
    this.width,
    this.height,
    this.durationSeconds,
    this.mediaType,
    this.metadataComplete = false,
    this.filename,
  });

  @override
  List<Object?> get props => [
    entryKey,
    url,
    takenAt,
    caption,
    thumbnailUrl,
    latitude,
    longitude,
    width,
    height,
    durationSeconds,
    mediaType,
    metadataComplete,
    filename,
  ];

  @override
  String toString() => 'ManifestEntry(entryKey: $entryKey, url: $url)';
}
