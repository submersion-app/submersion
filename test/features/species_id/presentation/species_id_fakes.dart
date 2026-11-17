import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/data/services/suggestion_acceptor.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';

import '../data/fake_vision_engine.dart';

/// Records what the viewer asks of the service; touches nothing.
class RecordingIdentificationService extends MediaIdentificationService {
  RecordingIdentificationService()
    : super(
        engine: FakeEngine(),
        loadPack: () async => null,
        identifications: MediaIdentificationRepository(),
        embeddings: IdentificationEmbeddingRepository(),
        crops: IdentificationCropStore(supportPath: () async => '/none'),
        resolveImage: (_) async => null,
        taggedSpecies: (_) async => const [],
        enabled: () => true,
      );

  final requested = <String>[];
  final locations = <GeoPoint?>[];
  final cancelled = <String>[];
  final reconciled = <String>[];
  final rejected = <(String, List<String>)>[];

  @override
  Future<void> request(MediaItem item, {GeoPoint? location}) async {
    requested.add(item.id);
    locations.add(location);
  }

  @override
  void cancelPending(String mediaId) => cancelled.add(mediaId);

  @override
  Future<void> reconcile(String mediaId) async => reconciled.add(mediaId);

  @override
  Future<void> reject(String mediaId, List<String> identificationIds) async =>
      rejected.add((mediaId, identificationIds));
}

/// Resolves every candidate to a species with the candidate's names.
class FakeAcceptor extends SuggestionAcceptor {
  FakeAcceptor() : super(species: SpeciesRepository());

  final resolved = <PackCandidate>[];

  @override
  Future<Species> resolve(PackCandidate candidate) async {
    resolved.add(candidate);
    return Species(
      id: candidate.catalogId ?? 'own-${candidate.gbifKey}',
      commonName: candidate.commonName,
      scientificName: candidate.scientificName,
      category: candidate.category,
      isBuiltIn: candidate.catalogId != null,
    );
  }
}

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

SpeciesSuggestion suggestion(
  PackCandidate candidate, {
  double score = 0.92,
  int count = 1,
  String cropId = 'i1',
  List<String>? ids,
}) => SpeciesSuggestion(
  top: NamedCandidate(candidate: candidate, score: score),
  score: score,
  count: count,
  cropIdentificationId: cropId,
  identificationIds: ids ?? [cropId],
  alternatives: [
    NamedCandidate(candidate: candidate, score: score),
    NamedCandidate(candidate: chromis, score: 0.05),
  ],
);
