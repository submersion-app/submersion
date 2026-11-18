import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/naming_level.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/services/naming_levels.dart';

import '../data/identification_fixtures.dart';
import 'manifest_fixture.dart';

// The fixture pack's own bars: floor 0.15, size 64, suggest 0.50 with a
// location and 0.70 without.
const _balanced = {
  'id': 'balanced',
  'target': 0.75,
  'suggestScore': 0.4,
  'suggestScoreNoLocation': 0.6,
  'precision': 0.8,
};
const _eager = {
  'id': 'eager',
  'target': 0.65,
  'suggestScore': 0.3,
  'suggestScoreNoLocation': 0.5,
  'precision': 0.7,
};

SpeciesPackManifest _pack({
  List<Map<String, Object?>> levels = const [],
  double? precision,
}) => SpeciesPackManifest.parse(
  manifestJson((m) {
    final naming = m['naming']! as Map<String, Object?>;
    naming['levels'] = levels;
    if (precision != null) naming['precision'] = precision;
  }),
);

/// An undecided photo identification whose best name scored [score].
MediaIdentification _named(
  double score, {
  bool located = true,
  double open = 0.42,
  int side = 480,
  bool suggestable = false,
}) => identification('i').copyWith(
  candidates: [
    NamedCandidate(
      candidate: const PackCandidate(
        gbifKey: 1,
        scientificName: 'Scarus vetula',
        commonName: 'Queen Parrotfish',
        category: SpeciesCategory.fish,
      ),
      score: score,
    ),
  ],
  locationLimited: located,
  openScore: open,
  boxPixelHeight: side,
  suggestable: suggestable,
);

void main() {
  group('levelInForce', () {
    test('is null with no pack', () {
      expect(levelInForce(null, NamingLevel.eager), isNull);
    });

    test('is the chosen level when the pack carries it', () {
      expect(
        levelInForce(_pack(levels: [_balanced, _eager]), NamingLevel.eager),
        const LevelInForce(
          level: NamingLevel.eager,
          packVersion: '2026.11.1',
          minCropSide: 64,
          minOpenScore: 0.15,
          suggestScore: 0.3,
          suggestScoreNoLocation: 0.5,
        ),
      );
    });

    test('falls back to the nearest surer level the pack carries', () {
      final balanced = levelInForce(
        _pack(levels: [_balanced]),
        NamingLevel.eager,
      )!;
      expect(balanced.level, NamingLevel.balanced);
      expect(
        (balanced.suggestScore, balanced.suggestScoreNoLocation),
        (0.4, 0.6),
      );
      final surer = levelInForce(_pack(), NamingLevel.eager)!;
      expect(surer.level, NamingLevel.surer);
      expect((surer.suggestScore, surer.suggestScoreNoLocation), (0.5, 0.7));
    });

    test('Surer is the pack own bars even when it carries levels', () {
      final surer = levelInForce(
        _pack(levels: [_balanced, _eager]),
        NamingLevel.surer,
      )!;
      expect((surer.suggestScore, surer.suggestScoreNoLocation), (0.5, 0.7));
    });
  });

  group('offeredLevels', () {
    test('is empty when the pack carries no levels', () {
      expect(offeredLevels(_pack().naming), isEmpty);
    });

    test('is Surer and the levels the pack carries', () {
      expect(offeredLevels(_pack(levels: [_balanced]).naming), [
        NamingLevel.surer,
        NamingLevel.balanced,
      ]);
      expect(offeredLevels(_pack(levels: [_balanced, _eager]).naming), [
        NamingLevel.surer,
        NamingLevel.balanced,
        NamingLevel.eager,
      ]);
    });
  });

  test('precisionOf reads each level and the pack own', () {
    final naming = _pack(levels: [_balanced], precision: 0.897).naming;
    expect(precisionOf(naming, NamingLevel.surer), 0.897);
    expect(precisionOf(naming, NamingLevel.balanced), 0.8);
    expect(precisionOf(naming, NamingLevel.eager), isNull);
    expect(precisionOf(_pack().naming, NamingLevel.surer), isNull);
  });

  test('accuracyPercent rounds down to a multiple of 5', () {
    expect(accuracyPercent(0.897), 85);
    expect(accuracyPercent(0.90), 90);
    expect(accuracyPercent(0.7999), 75);
    expect(accuracyPercent(1.0), 100);
    expect(accuracyPercent(0.07), 5);
  });

  group('applyNamingLevel', () {
    final pack = _pack(levels: [_balanced, _eager]);
    final surer = levelInForce(pack, NamingLevel.surer)!;
    final eager = levelInForce(pack, NamingLevel.eager)!;

    test('at Surer gives the flags the pack named them with', () {
      final rows = [
        _named(0.9, suggestable: true),
        _named(0.45),
        _named(0.65, located: false),
        _named(0.75, located: false, suggestable: true),
      ];
      final applied = applyNamingLevel(
        rows,
        level: surer,
        namedWithPack: '2026.11.1',
      );
      expect(
        [for (final i in applied) i.suggestable],
        [for (final i in rows) i.suggestable],
      );
    });

    test('at Eager names what clears its bars', () {
      final applied = applyNamingLevel(
        [
          _named(0.35),
          _named(0.45, located: false),
          _named(0.55, located: false),
        ],
        level: eager,
        namedWithPack: '2026.11.1',
      );
      expect([for (final i in applied) i.suggestable], [true, false, true]);
    });

    test('never names under the floor, under the size or with no name', () {
      final pending = track('t').copyWith(candidates: [], suggestable: false);
      final applied = applyNamingLevel(
        [_named(0.9, open: 0.1), _named(0.9, side: 50), pending],
        level: eager,
        namedWithPack: '2026.11.1',
      );
      expect([for (final i in applied) i.suggestable], [false, false, false]);
    });

    test('leaves rows another pack named, or with no run, as stored', () {
      final rows = [_named(0.35)];
      expect(
        applyNamingLevel(rows, level: eager, namedWithPack: '2026.10.1'),
        rows,
      );
      expect(applyNamingLevel(rows, level: eager, namedWithPack: null), rows);
      expect(
        applyNamingLevel(rows, level: null, namedWithPack: '2026.11.1'),
        rows,
      );
    });

    test('changes nothing but the suggestable flag', () {
      final rejected = _named(0.35).copyWith(
        decision: IdentificationDecision.rejected,
        confident: true,
        specific: false,
      );
      expect(
        applyNamingLevel(
          [rejected],
          level: eager,
          namedWithPack: '2026.11.1',
        ).single,
        rejected.copyWith(suggestable: true),
      );
    });
  });
}
