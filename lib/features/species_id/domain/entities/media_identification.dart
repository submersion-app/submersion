import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';

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

  NamedCandidate? get top => candidates.isEmpty ? null : candidates.first;

  int get boxShorterSide => math.min(boxPixelWidth, boxPixelHeight);

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

  MediaIdentificationRun copyWith({
    String? packVersion,
    int? Function()? locationCell,
    DateTime? analysedAt,
    int? detectionCount,
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
  ];
}

/// A species tagged on a photo, as the rules compare it with candidates.
class TaggedSpecies extends Equatable {
  const TaggedSpecies({required this.speciesId, this.scientificName});

  final String speciesId;
  final String? scientificName;

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
