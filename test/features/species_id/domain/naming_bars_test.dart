import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/domain/entities/naming_bars.dart';
import 'package:submersion/features/species_id/domain/entities/naming_level.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';

import 'manifest_fixture.dart';

/// The bars a run keeps from the pack that named it (issue #4876).
void main() {
  final pack = SpeciesPackManifest.parse(
    manifestJson((m) {
      final naming = m['naming']! as Map<String, Object?>;
      naming['provisional'] = false;
      naming['levels'] = [
        {
          'id': 'eager',
          'target': 0.65,
          'suggestScore': 0.3,
          'suggestScoreNoLocation': 0.5,
          'precision': 0.7,
        },
      ];
    }),
  );

  test('takes the pack naming bars and levels', () {
    final bars = NamingBars.fromNaming(pack.naming);
    expect(bars.minCropSide, pack.naming.minCropSide);
    expect(bars.minOpenScore, pack.naming.minOpenScore);
    expect(bars.suggestScore, pack.naming.suggestScore);
    expect(bars.suggestScoreNoLocation, pack.naming.suggestScoreNoLocation);
    expect(bars.levels.single.level, NamingLevel.eager);
  });

  test('reads back what it stored', () {
    final bars = NamingBars.fromNaming(pack.naming);
    expect(NamingBars.fromJson(bars.toJson()), bars);
  });

  test('reads nothing from no value, bad JSON or a wrong shape', () {
    expect(NamingBars.fromJson(null), isNull);
    expect(NamingBars.fromJson('not json'), isNull);
    expect(NamingBars.fromJson('[1, 2]'), isNull);
    expect(NamingBars.fromJson('{"minCropSide": "64"}'), isNull);
  });

  test('drops a level that does not read, keeping the bars', () {
    final bars = NamingBars.fromJson(
      '{"minCropSide": 64, "minOpenScore": 0.15, "suggestScore": 0.5, '
      '"suggestScoreNoLocation": 0.7, "levels": [{"id": "eager"}]}',
    );
    expect(bars, isNotNull);
    expect(bars!.levels, isEmpty);
  });

  test('copyWith replaces each field and keeps the rest', () {
    final bars = NamingBars.fromNaming(pack.naming);
    expect(bars.copyWith(), bars);
    final changed = bars.copyWith(
      minCropSide: 32,
      minOpenScore: 0.2,
      suggestScore: 0.6,
      suggestScoreNoLocation: 0.8,
      levels: const [],
    );
    expect(changed.minCropSide, 32);
    expect(changed.minOpenScore, 0.2);
    expect(changed.suggestScore, 0.6);
    expect(changed.suggestScoreNoLocation, 0.8);
    expect(changed.levels, isEmpty);
  });
}
