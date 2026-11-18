import 'dart:typed_data';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/services/region_grid.dart';

import '../domain/manifest_fixture.dart';

const fixtureParrotfish = PackCandidate(
  gbifKey: 1,
  scientificName: 'Scarus vetula',
  commonName: 'Queen Parrotfish',
  category: SpeciesCategory.fish,
  catalogId: 'sp_queen_parrotfish',
);
const fixtureChromis = PackCandidate(
  gbifKey: 2,
  scientificName: 'Chromis multilineata',
  commonName: 'Brown Chromis',
  category: SpeciesCategory.fish,
);
const fixtureTang = PackCandidate(
  gbifKey: 3,
  scientificName: 'Acanthurus coeruleus',
  commonName: 'Blue Tang',
  category: SpeciesCategory.fish,
);

/// A pack of three candidates with axis text embeddings, all recorded
/// everywhere, so a location never removes one.
LoadedPack fixturePack({
  String version = '2026.11.1',
  String detector = 'det-a',
  String classifier = 'clf-a',
}) {
  final manifest = SpeciesPackManifest.parse(
    manifestJson((m) {
      m['packVersion'] = version;
      (m['detector']! as Map)['id'] = detector;
      final c = m['classifier']! as Map;
      c['id'] = classifier;
      c['embeddingSize'] = 3;
      (m['naming']! as Map)['minAllowedCandidates'] = 1;
    }),
  );
  final grid = RegionGrid(cellDegrees: manifest.region.cellDegrees);
  final rowBytes = (grid.cellCount + 7) ~/ 8;
  return LoadedPack(
    pack: InstalledPack(
      manifest: manifest,
      directory: '/pack/$version',
      detectorPaths: ['/pack/$version/detector/detector.mlpackage'],
      classifierPath: '/pack/$version/classifier/classifier.mlpackage',
    ),
    candidates: const [fixtureParrotfish, fixtureChromis, fixtureTang],
    textEmbeddings: Float32List.fromList([1, 0, 0, 0, 1, 0, 0, 0, 1]),
    regions: RegionTable(
      grid: grid,
      bits: Uint8List(3 * rowBytes)..fillRange(0, 3 * rowBytes, 0xFF),
      candidateCount: 3,
    ),
  );
}
