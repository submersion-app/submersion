import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/track_sample.dart';

/// Shared identification fixtures for the species id data tests.

final fixtureT0 = DateTime.utc(2026, 11, 17, 10);
final fixtureT1 = DateTime.utc(2026, 11, 17, 11);

MediaIdentification identification(
  String id, {
  String mediaId = 'm1',
  IdentificationDecision decision = IdentificationDecision.undecided,
  String? decidedSpeciesId,
  DateTime? decidedAt,
}) => MediaIdentification(
  id: id,
  mediaId: mediaId,
  box: const IdentificationBox(x: 0.1, y: 0.2, width: 0.3, height: 0.25),
  boxPixelWidth: 640,
  boxPixelHeight: 480,
  detectorScore: 0.91,
  openScore: 0.42,
  candidates: const [
    NamedCandidate(
      candidate: PackCandidate(
        gbifKey: 2393681,
        scientificName: 'Scarus vetula',
        commonName: 'Queen Parrotfish',
        category: SpeciesCategory.fish,
        catalogId: 'sp_queen_parrotfish',
      ),
      score: 0.9,
    ),
    NamedCandidate(
      candidate: PackCandidate(
        gbifKey: 5,
        scientificName: 'Sparisoma viride',
        commonName: 'Stoplight Parrotfish',
        category: SpeciesCategory.fish,
      ),
      score: 0.05,
    ),
  ],
  locationLimited: true,
  suggestable: true,
  decision: decision,
  decidedSpeciesId: decidedSpeciesId,
  decidedAt: decidedAt,
  createdAt: fixtureT0,
);

MediaIdentificationRun run({String mediaId = 'm1', int count = 1}) =>
    MediaIdentificationRun(
      mediaId: mediaId,
      packVersion: '2026.11.1',
      detectorId: 'det',
      classifierId: 'clf',
      locationCell: 1462,
      analysedAt: fixtureT0,
      imageWidth: 4000,
      imageHeight: 3000,
      detectionCount: count,
    );

/// A fish followed through a video from [startMs] to [endMs], sampled every
/// 250 ms, drifting right by 0.01 a sample (issue #4675).
MediaIdentification track(
  String id, {
  String mediaId = 'v1',
  int startMs = 1000,
  int endMs = 2000,
  IdentificationDecision decision = IdentificationDecision.undecided,
  String? decidedSpeciesId,
  String? claimedSpeciesId,
  bool suggestable = true,
  bool confident = true,
  bool specific = true,
}) {
  final path = [
    for (var ms = startMs; ms <= endMs; ms += 250)
      TrackSample(
        ms: ms,
        box: IdentificationBox(
          x: 0.1 + (ms - startMs) / 25000,
          y: 0.4,
          width: 0.2,
          height: 0.1,
        ),
      ),
  ];
  return identification(
    id,
    mediaId: mediaId,
    decision: decision,
    decidedSpeciesId: decidedSpeciesId,
  ).copyWith(
    box: path[path.length ~/ 2].box,
    suggestable: suggestable,
    startMs: () => startMs,
    endMs: () => endMs,
    bestMs: () => path[path.length ~/ 2].ms,
    path: path,
    claimedSpeciesId: () => claimedSpeciesId,
    confident: confident,
    specific: specific,
  );
}

MediaIdentificationRun videoRun({
  String mediaId = 'v1',
  int count = 1,
  int? scannedMs = 10000,
  int? videoDurationMs = 25000,
}) => run(
  mediaId: mediaId,
  count: count,
).copyWith(scannedMs: () => scannedMs, videoDurationMs: () => videoDurationMs);
