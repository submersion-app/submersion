import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/insights/domain/tank_configuration/twin_set_candidates.dart';

/// Issue #3374: the name-and-size rule that used to classify a cylinder as a
/// twin set now only finds Back Gas cylinders the diver may want to re-role.
void main() {
  var nextId = 0;
  DiveTank tank(
    TankRole role, {
    double? volume,
    String? name,
    String? presetName,
  }) => DiveTank(
    id: 't${nextId++}',
    role: role,
    volume: volume,
    name: name,
    presetName: presetName,
  );

  group('looksLikeTwinSet', () {
    for (final name in [
      'Twin 12',
      'D12',
      'd7',
      'Doppel 10',
      'Doubles 12',
      '2x12',
      '2 x 7',
      '2×8.5',
      'Manifold 12',
    ]) {
      test('name "$name" is a twin set', () {
        expect(looksLikeTwinSet(tank(TankRole.backGas, name: name)), isTrue);
      });
    }

    for (final preset in ['twin_12', 'd12']) {
      test('preset "$preset" with no name is a twin set', () {
        expect(
          looksLikeTwinSet(tank(TankRole.backGas, presetName: preset)),
          isTrue,
        );
      });
    }

    for (final name in [
      'AL80',
      'HP100',
      'Steel 12',
      'Dive 12',
      'D',
      'D123',
      'ED12',
      // Volume by pressure, the usual European single label.
      'Steel 12x232',
      'Faber 12x300',
      '12 x 300',
      '232x12',
    ]) {
      test('name "$name" is not a twin set', () {
        expect(looksLikeTwinSet(tank(TankRole.backGas, name: name)), isFalse);
      });
    }

    test('no name and no preset is not a twin set', () {
      expect(looksLikeTwinSet(tank(TankRole.backGas)), isFalse);
    });
  });

  group('isTwinSetCandidate', () {
    test('a 24 L back gas is a candidate', () {
      expect(isTwinSetCandidate(tank(TankRole.backGas, volume: 24)), isTrue);
    });

    test('a twin set row is never a candidate', () {
      expect(isTwinSetCandidate(tank(TankRole.twinSet, volume: 24)), isFalse);
    });

    test('a 24 L stage is not a candidate', () {
      expect(isTwinSetCandidate(tank(TankRole.stage, volume: 24)), isFalse);
    });

    test('a back gas named D12 is a candidate', () {
      expect(isTwinSetCandidate(tank(TankRole.backGas, name: 'D12')), isTrue);
    });
  });
}
