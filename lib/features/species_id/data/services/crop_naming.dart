import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;

import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/services/region_grid.dart';
import 'package:submersion/features/species_id/domain/services/species_namer.dart';

/// Names crops off the UI isolate: with thousands of candidates it is
/// millions of multiplications a crop.
Future<List<NamingResult>> nameCrops(
  LoadedPack pack,
  List<({Float32List embedding, int shorterSide})> crops,
  int? cell,
) async {
  if (crops.isEmpty) return const [];
  final manifest = pack.pack.manifest;
  return compute(
    _nameAll,
    _NamingJob(
      candidates: pack.candidates,
      textEmbeddings: pack.textEmbeddings,
      embeddingSize: manifest.classifier.embeddingSize,
      logitScale: manifest.classifier.logitScale,
      naming: manifest.naming,
      regions: pack.regions,
      neighbourCells: manifest.region.neighbourCells,
      crops: crops,
      cell: cell,
    ),
  );
}

class _NamingJob {
  const _NamingJob({
    required this.candidates,
    required this.textEmbeddings,
    required this.embeddingSize,
    required this.logitScale,
    required this.naming,
    required this.regions,
    required this.neighbourCells,
    required this.crops,
    required this.cell,
  });

  final List<PackCandidate> candidates;
  final Float32List textEmbeddings;
  final int embeddingSize;
  final double logitScale;
  final NamingConfig naming;
  final RegionTable regions;
  final int neighbourCells;
  final List<({Float32List embedding, int shorterSide})> crops;
  final int? cell;
}

List<NamingResult> _nameAll(_NamingJob job) {
  final namer = SpeciesNamer(
    candidates: job.candidates,
    textEmbeddings: job.textEmbeddings,
    embeddingSize: job.embeddingSize,
    logitScale: job.logitScale,
    config: job.naming,
    regions: job.regions,
    neighbourCells: job.neighbourCells,
  );
  return [
    for (final crop in job.crops)
      namer.name(
        embedding: crop.embedding,
        boxShorterSide: crop.shorterSide,
        cell: job.cell,
      ),
  ];
}
