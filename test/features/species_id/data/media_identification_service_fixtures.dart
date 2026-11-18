/// What the media identification service tests share (issue #4668): a
/// small pack, a media item, and a repository that reports its reads.
library;

import 'dart:typed_data';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/services/region_grid.dart';

import '../domain/manifest_fixture.dart';

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
);

/// A pack of three candidates with axis text embeddings, all recorded
/// everywhere, so a location never removes one. With [secondDetector], a
/// format 2 pack carrying two detectors (issue #4691).
LoadedPack pack({
  String version = '2026.11.1',
  String detector = 'det-a',
  String? secondDetector,
  String classifier = 'clf-a',
  String? cropFit,
}) {
  void common(Map<String, Object?> m) {
    m['packVersion'] = version;
    final c = m['classifier']! as Map;
    c['id'] = classifier;
    c['embeddingSize'] = 3;
    if (cropFit != null) c['cropFit'] = cropFit;
    (m['naming']! as Map)['minAllowedCandidates'] = 1;
  }

  final manifest = SpeciesPackManifest.parse(
    secondDetector == null
        ? manifestJson((m) {
            common(m);
            (m['detector']! as Map)['id'] = detector;
          })
        : manifestV2Json((m) {
            common(m);
            detectorsOf(m)[0]['id'] = detector;
            detectorsOf(m)[1]['id'] = secondDetector;
          }),
  );
  final grid = RegionGrid(cellDegrees: manifest.region.cellDegrees);
  final rowBytes = (grid.cellCount + 7) ~/ 8;
  return LoadedPack(
    pack: InstalledPack(
      manifest: manifest,
      directory: '/pack/$version',
      detectorPaths: [
        for (final d in manifest.detectors)
          '/pack/$version/${d.file}/${d.file}.mlpackage',
      ],
      classifierPath: '/pack/$version/classifier/classifier.mlpackage',
    ),
    candidates: const [parrotfish, chromis, tang],
    textEmbeddings: Float32List.fromList([1, 0, 0, 0, 1, 0, 0, 0, 1]),
    regions: RegionTable(
      grid: grid,
      bits: Uint8List(3 * rowBytes)..fillRange(0, 3 * rowBytes, 0xFF),
      candidateCount: 3,
    ),
  );
}

/// Calls [onRead] after each read of a photo's identifications: where a
/// logbook switch would land between a read and the write after it.
class ReadHookRepository extends MediaIdentificationRepository {
  ReadHookRepository(AppDatabase database, this.onRead)
    : super(database: database);

  final void Function() onRead;

  @override
  Future<List<MediaIdentification>> forMedia(String mediaId) async {
    final found = await super.forMedia(mediaId);
    onRead();
    return found;
  }
}

MediaItem photo(String id, {MediaType type = MediaType.photo}) => MediaItem(
  id: id,
  mediaType: type,
  takenAt: DateTime.utc(2026, 5, 7, 12),
  createdAt: DateTime.utc(2026, 5, 7, 12),
  updatedAt: DateTime.utc(2026, 5, 7, 12),
);
