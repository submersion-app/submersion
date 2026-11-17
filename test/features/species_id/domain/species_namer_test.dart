import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/services/region_grid.dart';
import 'package:submersion/features/species_id/domain/services/species_namer.dart';

const _scale = 10.0;
const _grid = RegionGrid(cellDegrees: 30); // 12 columns, 6 rows

final _s3 = 1 / math.sqrt(3);

/// Four candidates whose text embeddings are the three axes and the
/// diagonal, so every expected score can be worked out by hand.
final _text = <List<double>>[
  [1, 0, 0],
  [0, 1, 0],
  [0, 0, 1],
  [_s3, _s3, _s3],
];

PackCandidate _candidate(int i) => PackCandidate(
  gbifKey: 100 + i,
  scientificName: 'Genus species$i',
  commonName: 'Fish $i',
  category: SpeciesCategory.fish,
);

NamingConfig _config({
  int minCropSide = 64,
  double minOpenScore = 0.0,
  double suggestScore = 0.5,
  double suggestScoreNoLocation = 0.7,
  int minAllowedCandidates = 1,
  int topK = 5,
}) => NamingConfig(
  provisional: true,
  minCropSide: minCropSide,
  minOpenScore: minOpenScore,
  suggestScore: suggestScore,
  confidentScore: 0.7,
  suggestScoreNoLocation: suggestScoreNoLocation,
  minAllowedCandidates: minAllowedCandidates,
  topK: topK,
);

/// One row per candidate, holding the cells it was recorded in.
RegionTable _regions(List<Set<int>> cellsPerCandidate) {
  final rowBytes = (_grid.cellCount + 7) ~/ 8;
  final bits = Uint8List(rowBytes * cellsPerCandidate.length);
  for (var i = 0; i < cellsPerCandidate.length; i++) {
    for (final c in cellsPerCandidate[i]) {
      bits[i * rowBytes + c ~/ 8] |= 1 << (c % 8);
    }
  }
  return RegionTable(
    grid: _grid,
    bits: bits,
    candidateCount: cellsPerCandidate.length,
  );
}

SpeciesNamer _namer({
  NamingConfig? config,
  List<Set<int>>? recorded,
  int neighbourCells = 0,
}) => SpeciesNamer(
  candidates: [for (var i = 0; i < _text.length; i++) _candidate(i)],
  textEmbeddings: Float32List.fromList([for (final t in _text) ...t]),
  embeddingSize: 3,
  logitScale: _scale,
  config: config ?? _config(),
  regions: _regions(recorded ?? [{}, {}, {}, {}]),
  neighbourCells: neighbourCells,
);

double _dot(List<double> a, List<double> b) =>
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2];

List<double> _unit(List<double> v) {
  final n = math.sqrt(_dot(v, v));
  return [for (final x in v) x / n];
}

/// Softmax shares, by the definition, over [indexes] only.
Map<int, double> _shares(List<double> embedding, Iterable<int> indexes) {
  final e = _unit(embedding);
  final exps = {
    for (final i in indexes) i: math.exp(_scale * _dot(e, _text[i])),
  };
  final sum = exps.values.fold(0.0, (a, b) => a + b);
  return {for (final i in exps.keys) i: exps[i]! / sum};
}

Float32List _f(List<double> v) => Float32List.fromList(v);

/// Over all four candidates its top share (candidate 0) is about 0.60:
/// between the 0.5 and 0.7 bars. Each test that uses it asserts that.
const _betweenBars = [1.0, 0.35, 0.3];

void main() {
  final cell = _grid.cellOf(12, -68);

  test('open score is the top share over every candidate', () {
    final e = [0.9, 0.3, 0.1];
    final result = _namer().name(embedding: _f(e), boxShorterSide: 200);

    final shares = _shares(e, [0, 1, 2, 3]);
    final top = shares.values.reduce(math.max);
    expect(result.openScore, closeTo(top, 1e-5));
    expect(result.candidates.first.candidate.gbifKey, 100);
  });

  test(
    'with no location every candidate competes and the higher bar applies',
    () {
      const e = _betweenBars;
      final shares = _shares(e, [0, 1, 2, 3]);
      final result = _namer().name(embedding: _f(e), boxShorterSide: 200);

      expect(result.locationLimited, isFalse);
      expect(result.candidates.first.score, closeTo(shares[0]!, 1e-5));
      // The premise: above the 0.5 bar, below the 0.7 one.
      expect(shares[0]!, inExclusiveRange(0.5, 0.7));
      expect(result.suggestable, isFalse);
    },
  );

  test('with a location, candidates not recorded nearby are dropped and the '
      'rest renormalised', () {
    final e = [1.0, 0.0, 0.0];
    final namer = _namer(
      recorded: [
        {cell},
        {cell},
        {},
        {},
      ],
    );
    final result = namer.name(
      embedding: _f(e),
      boxShorterSide: 200,
      cell: cell,
    );

    final shares = _shares(e, [0, 1]);
    expect(result.locationLimited, isTrue);
    expect(result.candidates.map((c) => c.candidate.gbifKey), [100, 101]);
    expect(result.candidates.first.score, closeTo(shares[0]!, 1e-5));
    expect(result.suggestable, shares[0]! >= 0.5);
    expect(result.suggestable, isTrue);
  });

  test('the open score is taken before limiting by place', () {
    final e = [1.0, 0.0, 0.0];
    final limited = _namer(
      recorded: [
        {cell},
        {cell},
        {},
        {},
      ],
    ).name(embedding: _f(e), boxShorterSide: 200, cell: cell);
    final open = _shares(e, [0, 1, 2, 3])[0]!;
    expect(limited.openScore, closeTo(open, 1e-5));
    expect(limited.candidates.first.score, greaterThan(limited.openScore));
  });

  test('a neighbouring cell counts as nearby', () {
    final next = cell + 1;
    final e = [1.0, 0.0, 0.0];
    final near = _namer(
      recorded: [
        {next},
        {},
        {},
        {},
      ],
      neighbourCells: 1,
    ).name(embedding: _f(e), boxShorterSide: 200, cell: cell);
    final far = _namer(
      recorded: [
        {next},
        {},
        {},
        {},
      ],
    ).name(embedding: _f(e), boxShorterSide: 200, cell: cell);

    expect(near.locationLimited, isTrue);
    expect(near.candidates.single.candidate.gbifKey, 100);
    // With no neighbours searched, nothing is allowed, which is fewer than
    // minAllowedCandidates, so every candidate competes.
    expect(far.locationLimited, isFalse);
    expect(far.candidates, hasLength(4));
  });

  test('fewer allowed than minAllowedCandidates falls back to every '
      'candidate and the higher bar', () {
    const e = _betweenBars;
    final result = _namer(
      config: _config(minAllowedCandidates: 3),
      recorded: [
        {cell},
        {cell},
        {},
        {},
      ],
    ).name(embedding: _f(e), boxShorterSide: 200, cell: cell);

    expect(result.locationLimited, isFalse);
    expect(result.candidates, hasLength(4));
    final shares = _shares(e, [0, 1, 2, 3]);
    expect(result.candidates.first.score, closeTo(shares[0]!, 1e-5));
    // Limited to the two recorded candidates it would have cleared the bar.
    expect(_shares(e, [0, 1])[0]!, greaterThan(0.7));
    expect(result.suggestable, isFalse);
  });

  test('not suggestable below minCropSide', () {
    final e = [1.0, 0.0, 0.0];
    final namer = _namer(
      recorded: [
        {cell},
        {cell},
        {},
        {},
      ],
    );
    expect(
      namer.name(embedding: _f(e), boxShorterSide: 64, cell: cell).suggestable,
      isTrue,
    );
    expect(
      namer.name(embedding: _f(e), boxShorterSide: 63, cell: cell).suggestable,
      isFalse,
    );
  });

  test('not suggestable below minOpenScore even when the limited score is '
      'high', () {
    // Halfway between the two allowed candidates and the diagonal: it looks
    // like nothing in particular against the whole list, yet one of two
    // allowed candidates still takes a large share.
    final e = [0.7, 0.6, 0.4];
    final open = _shares(e, [0, 1, 2, 3]).values.reduce(math.max);
    final limitedTop = _shares(e, [0, 1]).values.reduce(math.max);
    expect(limitedTop, greaterThan(0.5));

    final result = _namer(
      config: _config(minOpenScore: open + 0.01),
      recorded: [
        {cell},
        {cell},
        {},
        {},
      ],
    ).name(embedding: _f(e), boxShorterSide: 200, cell: cell);

    expect(result.locationLimited, isTrue);
    expect(result.candidates.first.score, closeTo(limitedTop, 1e-5));
    expect(result.suggestable, isFalse);
  });

  test('keeps at most topK, best first', () {
    final e = [0.9, 0.5, 0.2];
    final result = _namer(
      config: _config(topK: 2),
    ).name(embedding: _f(e), boxShorterSide: 200);
    final shares = _shares(e, [0, 1, 2, 3]).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    expect(result.candidates, hasLength(2));
    expect(result.candidates[0].candidate.gbifKey, 100 + shares[0].key);
    expect(result.candidates[1].candidate.gbifKey, 100 + shares[1].key);
    expect(
      result.candidates[0].score,
      greaterThanOrEqualTo(result.candidates[1].score),
    );
  });

  test('the embedding need not arrive normalised', () {
    final a = _namer().name(embedding: _f([3, 1, 0]), boxShorterSide: 200);
    final b = _namer().name(embedding: _f([0.3, 0.1, 0]), boxShorterSide: 200);
    expect(a.candidates.first.score, closeTo(b.candidates.first.score, 1e-5));
  });

  group('an unusable embedding', () {
    test('all zeros', () {
      expect(
        _namer().name(embedding: Float32List(3), boxShorterSide: 200),
        NamingResult.unusable,
      );
    });

    test('a NaN', () {
      expect(
        _namer().name(embedding: _f([double.nan, 0, 1]), boxShorterSide: 200),
        NamingResult.unusable,
      );
    });

    test('an infinity', () {
      expect(
        _namer().name(
          embedding: _f([double.infinity, 0, 1]),
          boxShorterSide: 200,
        ),
        NamingResult.unusable,
      );
    });

    test('the wrong length', () {
      expect(
        _namer().name(embedding: Float32List(5), boxShorterSide: 200),
        NamingResult.unusable,
      );
    });
  });

  test('a text table that does not fit the candidates is refused', () {
    expect(
      () => SpeciesNamer(
        candidates: [_candidate(0)],
        textEmbeddings: Float32List(4),
        embeddingSize: 3,
        logitScale: _scale,
        config: _config(),
        regions: _regions([{}]),
        neighbourCells: 0,
      ),
      throwsArgumentError,
    );
  });
}
