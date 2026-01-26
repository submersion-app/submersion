import 'package:equatable/equatable.dart';

/// Type of media (photo, video, instructor signature)
enum MediaType {
  photo,
  video,
  instructorSignature;

  String get displayName {
    switch (this) {
      case MediaType.photo:
        return 'Photo';
      case MediaType.video:
        return 'Video';
      case MediaType.instructorSignature:
        return 'Instructor Signature';
    }
  }

  static MediaType? fromString(String? value) {
    if (value == null) return null;
    return MediaType.values.cast<MediaType?>().firstWhere(
      (e) => e?.name == value,
      orElse: () => null,
    );
  }
}

/// Confidence level for depth/time matching from dive profile
enum MatchConfidence {
  exact,
  interpolated,
  estimated,
  noProfile;

  String get displayName {
    switch (this) {
      case MatchConfidence.exact:
        return 'Exact';
      case MatchConfidence.interpolated:
        return 'Interpolated';
      case MatchConfidence.estimated:
        return 'Estimated';
      case MatchConfidence.noProfile:
        return 'No Profile';
    }
  }

  static MatchConfidence? fromString(String? value) {
    if (value == null) return null;
    return MatchConfidence.values.cast<MatchConfidence?>().firstWhere(
      (e) => e?.name == value,
      orElse: () => null,
    );
  }
}

/// A media item (photo, video, or signature) associated with a dive
class MediaItem extends Equatable {
  final String id;
  final String? diveId;
  final String? siteId;
  final String? platformAssetId;
  final String? filePath;
  final String? originalFilename;
  final MediaType mediaType;
  final double? latitude;
  final double? longitude;
  final DateTime takenAt;
  final int? width;
  final int? height;
  final int? durationSeconds;
  final String? caption;
  final bool isFavorite;
  final String? thumbnailPath;
  final DateTime? thumbnailGeneratedAt;
  final DateTime? lastVerifiedAt;
  final bool isOrphaned;
  final String? signerId;
  final String? signerName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final MediaEnrichment? enrichment;

  const MediaItem({
    required this.id,
    this.diveId,
    this.siteId,
    this.platformAssetId,
    this.filePath,
    this.originalFilename,
    required this.mediaType,
    this.latitude,
    this.longitude,
    required this.takenAt,
    this.width,
    this.height,
    this.durationSeconds,
    this.caption,
    this.isFavorite = false,
    this.thumbnailPath,
    this.thumbnailGeneratedAt,
    this.lastVerifiedAt,
    this.isOrphaned = false,
    this.signerId,
    this.signerName,
    required this.createdAt,
    required this.updatedAt,
    this.enrichment,
  });

  /// Returns true if this media came from the device's photo gallery
  bool get isGalleryPhoto => platformAssetId != null;

  /// Returns true if this is a video
  bool get isVideo => mediaType == MediaType.video;

  /// Returns formatted duration string (e.g., "1:30" for 90 seconds)
  String? get durationString {
    if (durationSeconds == null) return null;
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  MediaItem copyWith({
    String? id,
    Object? diveId = _undefined,
    Object? siteId = _undefined,
    Object? platformAssetId = _undefined,
    Object? filePath = _undefined,
    Object? originalFilename = _undefined,
    MediaType? mediaType,
    Object? latitude = _undefined,
    Object? longitude = _undefined,
    DateTime? takenAt,
    Object? width = _undefined,
    Object? height = _undefined,
    Object? durationSeconds = _undefined,
    Object? caption = _undefined,
    bool? isFavorite,
    Object? thumbnailPath = _undefined,
    Object? thumbnailGeneratedAt = _undefined,
    Object? lastVerifiedAt = _undefined,
    bool? isOrphaned,
    Object? signerId = _undefined,
    Object? signerName = _undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? enrichment = _undefined,
  }) {
    return MediaItem(
      id: id ?? this.id,
      diveId: diveId == _undefined ? this.diveId : diveId as String?,
      siteId: siteId == _undefined ? this.siteId : siteId as String?,
      platformAssetId: platformAssetId == _undefined
          ? this.platformAssetId
          : platformAssetId as String?,
      filePath: filePath == _undefined ? this.filePath : filePath as String?,
      originalFilename: originalFilename == _undefined
          ? this.originalFilename
          : originalFilename as String?,
      mediaType: mediaType ?? this.mediaType,
      latitude: latitude == _undefined ? this.latitude : latitude as double?,
      longitude: longitude == _undefined
          ? this.longitude
          : longitude as double?,
      takenAt: takenAt ?? this.takenAt,
      width: width == _undefined ? this.width : width as int?,
      height: height == _undefined ? this.height : height as int?,
      durationSeconds: durationSeconds == _undefined
          ? this.durationSeconds
          : durationSeconds as int?,
      caption: caption == _undefined ? this.caption : caption as String?,
      isFavorite: isFavorite ?? this.isFavorite,
      thumbnailPath: thumbnailPath == _undefined
          ? this.thumbnailPath
          : thumbnailPath as String?,
      thumbnailGeneratedAt: thumbnailGeneratedAt == _undefined
          ? this.thumbnailGeneratedAt
          : thumbnailGeneratedAt as DateTime?,
      lastVerifiedAt: lastVerifiedAt == _undefined
          ? this.lastVerifiedAt
          : lastVerifiedAt as DateTime?,
      isOrphaned: isOrphaned ?? this.isOrphaned,
      signerId: signerId == _undefined ? this.signerId : signerId as String?,
      signerName: signerName == _undefined
          ? this.signerName
          : signerName as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      enrichment: enrichment == _undefined
          ? this.enrichment
          : enrichment as MediaEnrichment?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diveId,
    siteId,
    platformAssetId,
    filePath,
    originalFilename,
    mediaType,
    latitude,
    longitude,
    takenAt,
    width,
    height,
    durationSeconds,
    caption,
    isFavorite,
    thumbnailPath,
    thumbnailGeneratedAt,
    lastVerifiedAt,
    isOrphaned,
    signerId,
    signerName,
    createdAt,
    updatedAt,
    enrichment,
  ];
}

/// Enrichment data linking a media item to dive profile data
class MediaEnrichment extends Equatable {
  final String id;
  final String mediaId;
  final String diveId;
  final double? depthMeters;
  final double? temperatureCelsius;
  final int? elapsedSeconds;
  final MatchConfidence matchConfidence;
  final int? timestampOffsetSeconds;
  final DateTime createdAt;

  const MediaEnrichment({
    required this.id,
    required this.mediaId,
    required this.diveId,
    this.depthMeters,
    this.temperatureCelsius,
    this.elapsedSeconds,
    required this.matchConfidence,
    this.timestampOffsetSeconds,
    required this.createdAt,
  });

  MediaEnrichment copyWith({
    String? id,
    String? mediaId,
    String? diveId,
    Object? depthMeters = _undefined,
    Object? temperatureCelsius = _undefined,
    Object? elapsedSeconds = _undefined,
    MatchConfidence? matchConfidence,
    Object? timestampOffsetSeconds = _undefined,
    DateTime? createdAt,
  }) {
    return MediaEnrichment(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      diveId: diveId ?? this.diveId,
      depthMeters: depthMeters == _undefined
          ? this.depthMeters
          : depthMeters as double?,
      temperatureCelsius: temperatureCelsius == _undefined
          ? this.temperatureCelsius
          : temperatureCelsius as double?,
      elapsedSeconds: elapsedSeconds == _undefined
          ? this.elapsedSeconds
          : elapsedSeconds as int?,
      matchConfidence: matchConfidence ?? this.matchConfidence,
      timestampOffsetSeconds: timestampOffsetSeconds == _undefined
          ? this.timestampOffsetSeconds
          : timestampOffsetSeconds as int?,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    mediaId,
    diveId,
    depthMeters,
    temperatureCelsius,
    elapsedSeconds,
    matchConfidence,
    timestampOffsetSeconds,
    createdAt,
  ];
}

/// Tag linking a species to a specific location in a media item
class MediaSpeciesTag extends Equatable {
  final String id;
  final String mediaId;
  final String speciesId;
  final String? sightingId;

  /// Bounding box coordinates as normalized values (0.0-1.0)
  final double? bboxX;
  final double? bboxY;
  final double? bboxWidth;
  final double? bboxHeight;
  final String? notes;
  final DateTime createdAt;

  const MediaSpeciesTag({
    required this.id,
    required this.mediaId,
    required this.speciesId,
    this.sightingId,
    this.bboxX,
    this.bboxY,
    this.bboxWidth,
    this.bboxHeight,
    this.notes,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    mediaId,
    speciesId,
    sightingId,
    bboxX,
    bboxY,
    bboxWidth,
    bboxHeight,
    notes,
    createdAt,
  ];
}

/// A pending suggestion to link a photo from the gallery to a dive
class PendingPhotoSuggestion extends Equatable {
  final String id;
  final String diveId;
  final String platformAssetId;
  final DateTime takenAt;
  final String? thumbnailPath;
  final bool dismissed;
  final DateTime createdAt;

  const PendingPhotoSuggestion({
    required this.id,
    required this.diveId,
    required this.platformAssetId,
    required this.takenAt,
    this.thumbnailPath,
    this.dismissed = false,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    diveId,
    platformAssetId,
    takenAt,
    thumbnailPath,
    dismissed,
    createdAt,
  ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();
