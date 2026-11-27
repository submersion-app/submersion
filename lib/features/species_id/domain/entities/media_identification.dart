import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'package:submersion/features/species_id/domain/entities/naming_bars.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/scanned_ranges.dart';
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
    this.runId,
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

  /// The run that produced or last carried it (issue #4876). Undecided rows
  /// of another run lost a sync race and are not shown.
  final String? runId;

  NamedCandidate? get top => candidates.isEmpty ? null : candidates.first;

  int get boxShorterSide => math.min(boxPixelWidth, boxPixelHeight);

  /// One animal followed through a video, not a detection on a photo.
  bool get isTrack => startMs != null;

  /// A track a scan kept without a name when it stopped, so it is not
  /// lost: it has a path but no crop, embedding or candidates yet, shows
  /// no label, and is named when the scan resumes.
  bool get isPending => isTrack && bestMs == null;

  /// Whether the diver dismissed it and a re-analysis they asked for
  /// brought it back (issue #4825): undecided again, with the time of that
  /// still on it. It is shown and offered like any undecided one, and the
  /// app never tags it by itself: the dismissal it came from is the only
  /// record that the diver did not want that species here.
  bool get reopened =>
      decision == IdentificationDecision.undecided && decidedAt != null;

  /// Whether the diver said something on it: a decision, a species named
  /// from the frame, or a dismissal since brought back ([reopened]). A
  /// rescan carries this to the fresh track of the same animal; the app's
  /// own guesses are found again.
  bool get saidByDiver =>
      decision != IdentificationDecision.undecided ||
      claimedSpeciesId != null ||
      reopened;

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
    String? Function()? runId,
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
    runId: runId == null ? this.runId : runId(),
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
    runId,
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
    this.scannedRanges,
    this.analysedBy,
    this.runId,
    this.namingBars,
  });

  final String mediaId;

  /// The pack that analysed or last named it.
  final String packVersion;

  /// The pack's detector set (`SpeciesPackManifest.detectorSetId`). A
  /// video's detector id also names the version of the tracker that linked
  /// its tracks (`videoRunDetectorId`), so a new tracker scans it again.
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

  /// Video only (issue #4709): the stretches scanned, in any order the
  /// diver watched them. Null for a photo and for a run stored before they
  /// were kept; [scanned] then reads [scannedMs] as one stretch from 0.
  final ScannedRanges? scannedRanges;

  /// The sync device id of the device that analysed or last renamed it
  /// (issue #4876). Null only for a run from before v381 not yet published.
  final String? analysedBy;

  /// Minted when an analysis starts; kept by later chunks and renames.
  final String? runId;

  /// The naming bars of the pack that named it, or null when unknown.
  final NamingBars? namingBars;

  /// Whether it was made on the device whose sync id is [deviceId]. A run
  /// from before v381 was made on the device holding it.
  bool madeOn(String deviceId) => analysedBy == null || analysedBy == deviceId;

  /// The stretches of the video scanned so far.
  ScannedRanges get scanned =>
      scannedRanges ?? ScannedRanges.prefix(scannedMs ?? 0);

  /// Whether a video's scan has covered all of it.
  bool get scanComplete =>
      videoDurationMs != null && scanned.isComplete(videoDurationMs!);

  MediaIdentificationRun copyWith({
    String? packVersion,
    int? Function()? locationCell,
    DateTime? analysedAt,
    int? detectionCount,
    int? Function()? scannedMs,
    int? Function()? videoDurationMs,
    ScannedRanges? Function()? scannedRanges,
    String? Function()? analysedBy,
    String? Function()? runId,
    NamingBars? Function()? namingBars,
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
    scannedRanges: scannedRanges == null ? this.scannedRanges : scannedRanges(),
    analysedBy: analysedBy == null ? this.analysedBy : analysedBy(),
    runId: runId == null ? this.runId : runId(),
    namingBars: namingBars == null ? this.namingBars : namingBars(),
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
    scannedRanges,
    analysedBy,
    runId,
    namingBars,
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
