import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/services/region_grid.dart';
import 'package:submersion/features/species_id/domain/services/species_namer.dart';

/// The vectors the pack tools' copy of the namer writes
/// (tool/species_pack/naming.py). The accuracy scorer chooses the pack's
/// bars with that copy, so it must name every case exactly as the app does.
Map<String, Object?> _vectors() {
  final file = File(
    p.join('tool', 'species_pack', 'testdata', 'naming_vectors.json'),
  );
  return (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
}

double _num(Object? value) => (value! as num).toDouble();

void main() {
  final vectors = _vectors();
  final config = (vectors['config']! as Map).cast<String, Object?>();
  final text = [
    for (final row in vectors['textEmbeddings']! as List)
      [for (final v in row as List) _num(v)],
  ];
  final grid = RegionGrid(cellDegrees: vectors['cellDegrees']! as int);
  final recorded = [
    for (final row in vectors['recorded']! as List)
      {for (final c in row as List) c as int},
  ];
  final rowBytes = (grid.cellCount + 7) ~/ 8;
  final bits = Uint8List(rowBytes * recorded.length);
  for (var i = 0; i < recorded.length; i++) {
    for (final c in recorded[i]) {
      bits[i * rowBytes + c ~/ 8] |= 1 << (c % 8);
    }
  }

  final namer = SpeciesNamer(
    candidates: [
      for (var i = 0; i < text.length; i++)
        PackCandidate(
          gbifKey: 1000 + i,
          scientificName: 'Genus species$i',
          commonName: 'Fish $i',
          category: SpeciesCategory.fish,
        ),
    ],
    textEmbeddings: Float32List.fromList([for (final row in text) ...row]),
    embeddingSize: vectors['embeddingSize']! as int,
    logitScale: _num(vectors['logitScale']),
    config: NamingConfig(
      provisional: true,
      minCropSide: config['minCropSide']! as int,
      minOpenScore: _num(config['minOpenScore']),
      suggestScore: _num(config['suggestScore']),
      confidentScore: _num(config['confidentScore']),
      suggestScoreNoLocation: _num(config['suggestScoreNoLocation']),
      minAllowedCandidates: config['minAllowedCandidates']! as int,
      topK: config['topK']! as int,
    ),
    regions: RegionTable(
      grid: grid,
      bits: bits,
      candidateCount: recorded.length,
    ),
    neighbourCells: vectors['neighbourCells']! as int,
  );

  for (final raw in vectors['cases']! as List) {
    final c = (raw as Map).cast<String, Object?>();
    final expected = (c['expected']! as Map).cast<String, Object?>();
    test('${c['label']} names as the pack tools do', () {
      final result = namer.name(
        embedding: Float32List.fromList([
          for (final v in c['embedding']! as List) _num(v),
        ]),
        boxShorterSide: c['boxShorterSide']! as int,
        cell: c['cell'] as int?,
      );

      expect(result.openScore, closeTo(_num(expected['openScore']), 1e-9));
      expect(result.locationLimited, expected['locationLimited']);
      expect(result.suggestable, expected['suggestable']);
      final candidates = expected['candidates']! as List;
      expect(result.candidates, hasLength(candidates.length));
      for (var i = 0; i < candidates.length; i++) {
        final want = (candidates[i] as Map).cast<String, Object?>();
        expect(
          result.candidates[i].candidate.gbifKey,
          1000 + (want['index']! as int),
        );
        expect(result.candidates[i].score, closeTo(_num(want['score']), 1e-9));
      }
    });
  }
}
