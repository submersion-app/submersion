import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/track_sample.dart';

/// What the diver made of one of the app's identifications.
enum IdentificationDecision { undecided, accepted, rejected }

/// Where an animal is, normalised 0 to 1 against the analysed image after
/// its orientation is applied: the same convention as people tags.
class IdentificationBox extends Equatable {
  const IdentificationBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  double get area => width * height;

  /// Intersection over union: 1 for the same box, 0 for disjoint ones.
  double iou(IdentificationBox other) {
    final left = math.max(x, other.x);
    final top = math.max(y, other.y);
    final right = math.min(x + width, other.x + other.width);
    final bottom = math.min(y + height, other.y + other.height);
    if (right <= left || bottom <= top) return 0;
    final intersection = (right - left) * (bottom - top);
    final union = area + other.area - intersection;
    return union <= 0 ? 0 : intersection / union;
  }

  IdentificationBox copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
  }) => IdentificationBox(
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
  );

  @override
  List<Object?> get props => [x, y, width, height];
}

/// One animal the app found on a piece of media.
class MediaIdentification extends Equatable {
  const MediaIdentification({
    required this.id,
    required this.mediaId,
    required this.box,
    required this.boxPixelWidth,
    required this.boxPixelHeight,
    required this.detectorScore,
    required this.openScore,
    required this.candidates,
    required this.locationLimited,
    required this.suggestable,
    required this.decision,
    this.decidedSpeciesId,
    this.decidedAt,
    required this.createdAt,
    this.startMs,
    this.endMs,
    this.bestMs,
    this.path = const [],
    this.claimedSpeciesId,
    this.confident = false,
    this.specific = false,
  });

  final String id;
  final String mediaId;
  final IdentificationBox box;

  /// The box's size in the analysed image's pixels.
  final int boxPixelWidth;
  final int boxPixelHeight;
  final double detectorScore;
  final double openScore;

  /// Best first, with their names, so a suggestion stays usable after the
  /// model pack is removed.
  final List<NamedCandidate> candidates;
  final bool locationLimited;

  /// Whether it passed the bars when it was last named.
  final bool suggestable;
  final IdentificationDecision decision;

  /// The species tagged, once accepted.
  final String? decidedSpeciesId;
  final DateTime? decidedAt;
  final DateTime createdAt;

  /// Video only (issue #4675): when the animal was first and last seen,
  /// and the moment the box, crop and pixel size are from, in milliseconds
  /// from the start of the video. Null on a photo.
  final int? startMs;
  final int? endMs;
  final int? bestMs;

  /// Video only: the box at each sample, oldest first.
  final List<TrackSample> path;

  /// The species the diver gave this animal from the frame, before the tag
  /// is written. It wins over the name rules.
  final String? claimedSpeciesId;

  /// Whether it passed the confident bar when it was last named.
  final bool confident;

  /// Whether its open score passed the floor when it was last named: it
  /// looks like something in particular, not a hand or open water.
  final bool specific;

  NamedCandidate? get top => candidates.isEmpty ? null : candidates.first;

  int get boxShorterSide => math.min(boxPixelWidth, boxPixelHeight);

  /// One animal followed through a video, not a detection on a photo.
  bool get isTrack => startMs != null;

  /// A track a scan kept without a name when it stopped, so it is not
  /// lost: it has a path but no crop, embedding or candidates yet, shows
  /// no label, and is named when the scan resumes.
  bool get isPending => isTrack && bestMs == null;

  int get durationMs => isTrack ? (endMs ?? startMs!) - startMs! : 0;

  MediaIdentification copyWith({
    String? id,
    String? mediaId,
    IdentificationBox? box,
    int? boxPixelWidth,
    int? boxPixelHeight,
    double? detectorScore,
    double? openScore,
    List<NamedCandidate>? candidates,
    bool? locationLimited,
    bool? suggestable,
    IdentificationDecision? decision,
    String? decidedSpeciesId,
    DateTime? decidedAt,
    DateTime? createdAt,
    int? Function()? startMs,
    int? Function()? endMs,
    int? Function()? bestMs,
    List<TrackSample>? path,
    String? Function()? claimedSpeciesId,
    bool? confident,
    bool? specific,
  }) => MediaIdentification(
    id: id ?? this.id,
    mediaId: mediaId ?? this.mediaId,
    box: box ?? this.box,
    boxPixelWidth: boxPixelWidth ?? this.boxPixelWidth,
    boxPixelHeight: boxPixelHeight ?? this.boxPixelHeight,
    detectorScore: detectorScore ?? this.detectorScore,
    openScore: openScore ?? this.openScore,
    candidates: candidates ?? this.candidates,
    locationLimited: locationLimited ?? this.locationLimited,
    suggestable: suggestable ?? this.suggestable,
    decision: decision ?? this.decision,
    decidedSpeciesId: decidedSpeciesId ?? this.decidedSpeciesId,
    decidedAt: decidedAt ?? this.decidedAt,
    createdAt: createdAt ?? this.createdAt,
    startMs: startMs == null ? this.startMs : startMs(),
    endMs: endMs == null ? this.endMs : endMs(),
    bestMs: bestMs == null ? this.bestMs : bestMs(),
    path: path ?? this.path,
    claimedSpeciesId: claimedSpeciesId == null
        ? this.claimedSpeciesId
        : claimedSpeciesId(),
    confident: confident ?? this.confident,
    specific: specific ?? this.specific,
  );

  @override
  List<Object?> get props => [
    id,
    mediaId,
    box,
    boxPixelWidth,
    boxPixelHeight,
    detectorScore,
    openScore,
    candidates,
    locationLimited,
    suggestable,
    decision,
    decidedSpeciesId,
    decidedAt,
    createdAt,
    startMs,
    endMs,
    bestMs,
    path,
    claimedSpeciesId,
    confident,
    specific,
  ];
}

/// That a piece of media was analysed, with what, and against which place.
class MediaIdentificationRun extends Equatable {
  const MediaIdentificationRun({
    required this.mediaId,
    required this.packVersion,
    required this.detectorId,
    required this.classifierId,
    this.locationCell,
    required this.analysedAt,
    required this.imageWidth,
    required this.imageHeight,
    required this.detectionCount,
    this.scannedMs,
    this.videoDurationMs,
  });

  final String mediaId;

  /// The pack that analysed or last named it.
  final String packVersion;
  final String detectorId;
  final String classifierId;

  /// The grid cell naming used, or null for none.
  final int? locationCell;
  final DateTime analysedAt;
  final int imageWidth;
  final int imageHeight;
  final int detectionCount;

  /// Video only (issue #4675): how far the scan has got, and the video's
  /// length as the engine read it, in milliseconds. Null for a photo.
  final int? scannedMs;
  final int? videoDurationMs;

  /// Whether a video's scan has reached its end.
  bool get scanComplete =>
      videoDurationMs != null && (scannedMs ?? 0) >= videoDurationMs!;

  MediaIdentificationRun copyWith({
    String? packVersion,
    int? Function()? locationCell,
    DateTime? analysedAt,
    int? detectionCount,
    int? Function()? scannedMs,
    int? Function()? videoDurationMs,
  }) => MediaIdentificationRun(
    mediaId: mediaId,
    packVersion: packVersion ?? this.packVersion,
    detectorId: detectorId,
    classifierId: classifierId,
    locationCell: locationCell == null ? this.locationCell : locationCell(),
    analysedAt: analysedAt ?? this.analysedAt,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    detectionCount: detectionCount ?? this.detectionCount,
    scannedMs: scannedMs == null ? this.scannedMs : scannedMs(),
    videoDurationMs: videoDurationMs == null
        ? this.videoDurationMs
        : videoDurationMs(),
  );

  @override
  List<Object?> get props => [
    mediaId,
    packVersion,
    detectorId,
    classifierId,
    locationCell,
    analysedAt,
    imageWidth,
    imageHeight,
    detectionCount,
    scannedMs,
    videoDurationMs,
  ];
}

/// A species tagged on a photo, as the rules compare it with candidates.
class TaggedSpecies extends Equatable {
  const TaggedSpecies({required this.speciesId, this.scientificName});

  final String speciesId;
  final String? scientificName;

  TaggedSpecies copyWith({
    String? speciesId,
    String? Function()? scientificName,
  }) => TaggedSpecies(
    speciesId: speciesId ?? this.speciesId,
    scientificName: scientificName == null
        ? this.scientificName
        : scientificName(),
  );

  @override
  List<Object?> get props => [speciesId, scientificName];
}

/// What the viewer offers: one species, however many animals of it the
/// photo shows.
class SpeciesSuggestion extends Equatable {
  const SpeciesSuggestion({
    required this.top,
    required this.score,
    required this.count,
    required this.cropIdentificationId,
    required this.identificationIds,
    required this.alternatives,
  });

  final NamedCandidate top;

  /// The best of the group's scores.
  final double score;
  final int count;

  /// The identification whose crop is shown.
  final String cropIdentificationId;
  final List<String> identificationIds;

  /// The shown crop's candidates, at most three.
  final List<NamedCandidate> alternatives;

  SpeciesSuggestion copyWith({
    NamedCandidate? top,
    double? score,
    int? count,
    String? cropIdentificationId,
    List<String>? identificationIds,
    List<NamedCandidate>? alternatives,
  }) => SpeciesSuggestion(
    top: top ?? this.top,
    score: score ?? this.score,
    count: count ?? this.count,
    cropIdentificationId: cropIdentificationId ?? this.cropIdentificationId,
    identificationIds: identificationIds ?? this.identificationIds,
    alternatives: alternatives ?? this.alternatives,
  );

  @override
  List<Object?> get props => [
    top,
    score,
    count,
    cropIdentificationId,
    identificationIds,
    alternatives,
  ];
}
