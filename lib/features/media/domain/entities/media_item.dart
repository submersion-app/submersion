import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:submersion/features/media/domain/entities/media_dive_window.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

/// Type of media (photo, video, instructor signature)
enum MediaType {
  photo,
  video,
  instructorSignature,
  document;

  String get displayName {
    switch (this) {
      case MediaType.photo:
        return 'Photo';
      case MediaType.video:
        return 'Video';
      case MediaType.instructorSignature:
        return 'Instructor Signature';
      case MediaType.document:
        return 'Document';
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
  noProfile,

  /// The diver pinned the item to a moment in the dive themselves
  /// ([MediaItem.manualElapsedSeconds]); depth and temperature are read
  /// from the profile at that offset. Never an estimate, never reverted
  /// by a backfill, and never subject to the dive-window tolerance.
  manual;

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
      case MatchConfidence.manual:
        return 'Manual';
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
  final Uint8List? imageData;
  final MediaSourceType sourceType;
  final String? localPath;
  final String? bookmarkRef;
  final String? url;
  final String? subscriptionId;
  final String? entryKey;
  final String? connectorAccountId;
  final String? remoteAssetId;
  final String? originDeviceId;
  final String? contentHash;
  final int? contentSizeBytes;
  final DateTime? remoteUploadedAt;
  final DateTime? remoteThumbUploadedAt;
  final String? compressedLevel;
  final int? compressedSizeBytes;
  final DateTime? remoteCompressedUploadedAt;

  /// Media section Phase 2: explicitly kept in the library while unlinked.
  /// The orphan sweep never GCs retained rows' store blobs.
  final bool retainInLibrary;

  /// Seconds from the dive start the diver pinned this item to, overriding
  /// the position derived from [takenAt] (issue #1090). Null means the
  /// automatic position applies. [takenAt] itself is never rewritten: it is
  /// the file's own timestamp and gallery re-resolution matches on it.
  final int? manualElapsedSeconds;

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
    this.imageData,
    this.sourceType = MediaSourceType.platformGallery,
    this.localPath,
    this.bookmarkRef,
    this.url,
    this.subscriptionId,
    this.entryKey,
    this.connectorAccountId,
    this.remoteAssetId,
    this.originDeviceId,
    this.contentHash,
    this.contentSizeBytes,
    this.remoteUploadedAt,
    this.remoteThumbUploadedAt,
    this.compressedLevel,
    this.compressedSizeBytes,
    this.remoteCompressedUploadedAt,
    this.retainInLibrary = false,
    this.manualElapsedSeconds,
    required this.createdAt,
    required this.updatedAt,
    this.enrichment,
  });

  /// Returns true if this media came from the device's photo gallery
  bool get isGalleryPhoto => platformAssetId != null;

  /// Returns true if this is a video
  bool get isVideo => mediaType == MediaType.video;

  /// True for attachment documents (PDFs and opaque files).
  bool get isDocument => mediaType == MediaType.document;

  /// Lowercased extension of [originalFilename] without the dot; '' when
  /// absent. Presentation-only: storage addressing uses StoreKeys.
  String get documentExtension {
    final name = originalFilename;
    if (name == null) return '';
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  /// True for documents that render in the in-app PDF viewer.
  bool get isPdf => isDocument && documentExtension == 'pdf';

  /// Filename to use when writing this item's bytes to a temp file for
  /// sharing. Falls back to a media-type-appropriate default when
  /// [originalFilename] is missing or blank -- some import sources (e.g.
  /// the desktop file picker) report an empty string rather than null,
  /// which a plain `??` fallback misses and produces an empty path.
  String get shareFilename {
    final name = originalFilename;
    if (name != null && name.isNotEmpty) return name;
    return isVideo ? 'dive_video.mp4' : 'dive_photo.jpg';
  }

  /// MIME type to advertise when sharing this item, derived from
  /// [shareFilename]'s extension so the advertised type never disagrees with
  /// the filename (and likely the bytes) some share targets inspect. Falls
  /// back to a media-type-appropriate default for a missing or unrecognized
  /// extension.
  String get shareMimeType {
    final name = shareFilename;
    final dot = name.lastIndexOf('.');
    final ext = dot >= 0 && dot < name.length - 1
        ? name.substring(dot + 1).toLowerCase()
        : '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'm4v':
        return 'video/x-m4v';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'gpx':
        return 'application/gpx+xml';
      default:
        if (isDocument) return 'application/octet-stream';
        return isVideo ? 'video/mp4' : 'image/jpeg';
    }
  }

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
    Object? imageData = _undefined,
    MediaSourceType? sourceType,
    Object? localPath = _undefined,
    Object? bookmarkRef = _undefined,
    Object? url = _undefined,
    Object? subscriptionId = _undefined,
    Object? entryKey = _undefined,
    Object? connectorAccountId = _undefined,
    Object? remoteAssetId = _undefined,
    Object? originDeviceId = _undefined,
    Object? contentHash = _undefined,
    Object? contentSizeBytes = _undefined,
    Object? remoteUploadedAt = _undefined,
    Object? remoteThumbUploadedAt = _undefined,
    Object? compressedLevel = _undefined,
    Object? compressedSizeBytes = _undefined,
    Object? remoteCompressedUploadedAt = _undefined,
    bool? retainInLibrary,
    Object? manualElapsedSeconds = _undefined,
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
      imageData: imageData == _undefined
          ? this.imageData
          : imageData as Uint8List?,
      sourceType: sourceType ?? this.sourceType,
      localPath: localPath == _undefined
          ? this.localPath
          : localPath as String?,
      bookmarkRef: bookmarkRef == _undefined
          ? this.bookmarkRef
          : bookmarkRef as String?,
      url: url == _undefined ? this.url : url as String?,
      subscriptionId: subscriptionId == _undefined
          ? this.subscriptionId
          : subscriptionId as String?,
      entryKey: entryKey == _undefined ? this.entryKey : entryKey as String?,
      connectorAccountId: connectorAccountId == _undefined
          ? this.connectorAccountId
          : connectorAccountId as String?,
      remoteAssetId: remoteAssetId == _undefined
          ? this.remoteAssetId
          : remoteAssetId as String?,
      originDeviceId: originDeviceId == _undefined
          ? this.originDeviceId
          : originDeviceId as String?,
      contentHash: contentHash == _undefined
          ? this.contentHash
          : contentHash as String?,
      contentSizeBytes: contentSizeBytes == _undefined
          ? this.contentSizeBytes
          : contentSizeBytes as int?,
      remoteUploadedAt: remoteUploadedAt == _undefined
          ? this.remoteUploadedAt
          : remoteUploadedAt as DateTime?,
      remoteThumbUploadedAt: remoteThumbUploadedAt == _undefined
          ? this.remoteThumbUploadedAt
          : remoteThumbUploadedAt as DateTime?,
      compressedLevel: compressedLevel == _undefined
          ? this.compressedLevel
          : compressedLevel as String?,
      compressedSizeBytes: compressedSizeBytes == _undefined
          ? this.compressedSizeBytes
          : compressedSizeBytes as int?,
      remoteCompressedUploadedAt: remoteCompressedUploadedAt == _undefined
          ? this.remoteCompressedUploadedAt
          : remoteCompressedUploadedAt as DateTime?,
      retainInLibrary: retainInLibrary ?? this.retainInLibrary,
      manualElapsedSeconds: manualElapsedSeconds == _undefined
          ? this.manualElapsedSeconds
          : manualElapsedSeconds as int?,
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
    imageData,
    sourceType,
    localPath,
    bookmarkRef,
    url,
    subscriptionId,
    entryKey,
    connectorAccountId,
    remoteAssetId,
    originDeviceId,
    contentHash,
    contentSizeBytes,
    remoteUploadedAt,
    remoteThumbUploadedAt,
    compressedLevel,
    compressedSizeBytes,
    remoteCompressedUploadedAt,
    retainInLibrary,
    manualElapsedSeconds,
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

  /// Whether the diver placed this item in the dive themselves.
  bool get isManual => matchConfidence == MatchConfidence.manual;

  /// Whether this row positions the item somewhere the chart should draw.
  ///
  /// An automatic position is only trusted inside [MediaDiveWindow] around a
  /// profile of [profileLengthSeconds]; a manual one always is. The chart,
  /// the 3D scene and the viewer all ask this rather than clamping blindly,
  /// so a wrong capture date cannot pin a marker to the exit (issue #1090).
  bool isWithinDiveWindow(int profileLengthSeconds) {
    final seconds = elapsedSeconds;
    if (seconds == null) return false;
    if (matchConfidence == MatchConfidence.noProfile) return false;
    if (isManual) return true;
    return MediaDiveWindow.contains(
      elapsedSeconds: seconds,
      profileLengthSeconds: profileLengthSeconds,
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

/// A pending suggestion to link a photo from the gallery or an external
/// connector (Lightroom) to a dive
class PendingPhotoSuggestion extends Equatable {
  final String id;
  final String diveId;
  final String platformAssetId;
  final DateTime takenAt;
  final String? thumbnailPath;
  final bool dismissed;
  final DateTime createdAt;

  /// Set on connector suggestions: the ConnectedAccounts roster row and the
  /// service-side asset id. Null on device-gallery suggestions.
  final String? connectorAccountId;
  final String? remoteAssetId;

  const PendingPhotoSuggestion({
    required this.id,
    required this.diveId,
    required this.platformAssetId,
    required this.takenAt,
    this.thumbnailPath,
    this.dismissed = false,
    required this.createdAt,
    this.connectorAccountId,
    this.remoteAssetId,
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
    connectorAccountId,
    remoteAssetId,
  ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();
