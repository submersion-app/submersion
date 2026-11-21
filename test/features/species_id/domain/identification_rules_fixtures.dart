import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';

/// What the identification rules tests share: a few species, one stored
/// identification and one run, all on media m1.

final ruleNow = DateTime.utc(2026, 11, 17, 12);
final ruleEarlier = DateTime.utc(2026, 11, 1);

const parrotfish = PackCandidate(
  gbifKey: 1,
  scientificName: 'Scarus vetula',
  commonName: 'Queen Parrotfish',
  category: SpeciesCategory.fish,
  catalogId: 'sp_queen_parrotfish',
);
const chromis = PackCandidate(
  gbifKey: 2,
  scientificName: 'Chromis multilineata',
  commonName: 'Brown Chromis',
  category: SpeciesCategory.fish,
);
const tang = PackCandidate(
  gbifKey: 3,
  scientificName: 'Acanthurus coeruleus',
  commonName: 'Blue Tang',
  category: SpeciesCategory.fish,
  catalogId: 'sp_blue_tang',
);

MediaIdentification ruleId(
  String id, {
  List<(PackCandidate, double)> candidates = const [(parrotfish, 0.9)],
  bool suggestable = true,
  IdentificationDecision decision = IdentificationDecision.undecided,
  String? decidedSpeciesId,
  IdentificationBox box = const IdentificationBox(
    x: 0.1,
    y: 0.1,
    width: 0.2,
    height: 0.2,
  ),
}) => MediaIdentification(
  id: id,
  mediaId: 'm1',
  box: box,
  boxPixelWidth: 200,
  boxPixelHeight: 150,
  detectorScore: 0.8,
  openScore: 0.5,
  candidates: [
    for (final (c, s) in candidates) NamedCandidate(candidate: c, score: s),
  ],
  locationLimited: true,
  suggestable: suggestable,
  decision: decision,
  decidedSpeciesId: decidedSpeciesId,
  decidedAt: decision == IdentificationDecision.undecided ? null : ruleEarlier,
  createdAt: ruleEarlier,
);

MediaIdentificationRun ruleRun({
  String pack = '2026.11.1',
  String detector = 'det-a',
  String classifier = 'clf-a',
  int? cell = 1462,
}) => MediaIdentificationRun(
  mediaId: 'm1',
  packVersion: pack,
  detectorId: detector,
  classifierId: classifier,
  locationCell: cell,
  analysedAt: ruleEarlier,
  imageWidth: 4000,
  imageHeight: 3000,
  detectionCount: 1,
);
