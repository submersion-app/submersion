import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/data_quality/domain/repairs/duplicate_cylinder_rules.dart';

DiveTank _tank(
  String id, {
  String? serial,
  String? sourceId,
  String? computerId,
  double o2 = 21,
  double he = 0,
  double? volume,
  double? workingPressure,
  String? name,
  String? equipmentId,
}) => DiveTank(
  id: id,
  diveId: 'dive',
  o2Percent: o2,
  hePercent: he,
  tankOrder: 0,
  tankRole: 'backGas',
  transmitterSerial: serial,
  sourceId: sourceId,
  computerId: computerId,
  volume: volume,
  workingPressure: workingPressure,
  tankName: name,
  equipmentId: equipmentId,
);

/// Which cylinders are one, and which of them stays (issue #4393).
void main() {
  group('serialGroups', () {
    test('serial groups ignore case and whitespace', () {
      final groups = serialGroups([
        _tank('a', serial: 'ab12'),
        _tank('b', serial: ' AB12 '),
      ]);
      expect(groups, [
        ['a', 'b'],
      ]);
    });

    test('all-zero serials are no transmitter, as the detector reads them', () {
      final groups = serialGroups([
        _tank('a', serial: '000'),
        _tank('b', serial: '000'),
      ]);
      expect(groups, isEmpty);
    });

    test('serial groups skip tanks without a serial', () {
      final groups = serialGroups([
        _tank('a'),
        _tank('b', serial: ''),
        _tank('c', serial: 'X1'),
      ]);
      expect(groups, isEmpty);
    });

    test('three tanks on one serial form one group', () {
      final groups = serialGroups([
        _tank('c', serial: 'X1'),
        _tank('a', serial: 'X1'),
        _tank('b', serial: 'X1'),
        _tank('d', serial: 'Y2'),
      ]);
      expect(groups, [
        ['a', 'b', 'c'],
      ]);
    });
  });

  group('duplicateGroupFor', () {
    final tanks = [
      _tank('a', serial: 'X1'),
      _tank('b', serial: 'X1'),
      _tank('c', serial: 'X1'),
      _tank('d'),
    ];

    test('a serial-proven twin brings its whole serial group', () {
      expect(
        duplicateGroupFor(
          tankIdA: 'a',
          tankIdB: 'b',
          sameTransmitter: true,
          tanks: tanks,
        ),
        ['a', 'b', 'c'],
      );
    });

    test('a stale twin whose second tank left the serial group is empty', () {
      expect(
        duplicateGroupFor(
          tankIdA: 'a',
          tankIdB: 'd',
          sameTransmitter: true,
          tanks: tanks,
        ),
        isEmpty,
      );
    });

    test('curve-only twins form a pair', () {
      expect(
        duplicateGroupFor(
          tankIdA: 'a',
          tankIdB: 'd',
          sameTransmitter: false,
          tanks: tanks,
        ),
        ['a', 'd'],
      );
    });

    test('stale ids are dropped', () {
      expect(
        duplicateGroupFor(
          tankIdA: 'a',
          tankIdB: 'gone',
          sameTransmitter: false,
          tanks: tanks,
        ),
        isEmpty,
      );
    });
  });

  group('pickSurvivor', () {
    test('survivor is the primary source tank', () {
      final survivor = pickSurvivor([
        _tank('a', sourceId: 'secondary', volume: 11.1, name: 'AL80'),
        _tank('b', sourceId: 'primary'),
      ], primarySourceId: 'primary');
      expect(survivor, 'b');
    });

    test('an unattributed tank is the primary source tank', () {
      final survivor = pickSurvivor(
        [
          _tank('a', sourceId: 'secondary', volume: 11.1, name: 'AL80'),
          _tank('b'),
        ],
        primarySourceId: 'primary',
        primaryComputerId: 'dc-p',
      );
      expect(survivor, 'b');
    });

    test(
      "a tank on the primary's computer with no source is the primary's",
      () {
        final survivor = pickSurvivor(
          [
            _tank('a', sourceId: 'secondary', volume: 11.1),
            _tank('b', computerId: 'dc-p'),
          ],
          primarySourceId: 'primary',
          primaryComputerId: 'dc-p',
        );
        expect(survivor, 'b');
      },
    );

    test('without a primary tank the most detailed tank survives', () {
      final survivor = pickSurvivor([
        _tank('a', volume: 11.1),
        _tank('b', volume: 11.1, workingPressure: 207, equipmentId: 'gear'),
      ], primarySourceId: 'primary');
      expect(survivor, 'b');
    });

    test('when every tank is the primary source, detail decides', () {
      final survivor = pickSurvivor([
        _tank('a', sourceId: 'primary'),
        _tank('b', sourceId: 'primary', name: 'Twin left'),
      ], primarySourceId: 'primary');
      expect(survivor, 'b');
    });

    test('ties go to the lowest id', () {
      final survivor = pickSurvivor([
        _tank('b'),
        _tank('a'),
      ], primarySourceId: null);
      expect(survivor, 'a');
    });

    test('gas mix does not count as detail', () {
      final survivor = pickSurvivor([
        _tank('b', o2: 32),
        _tank('a', o2: 21),
      ], primarySourceId: null);
      expect(survivor, 'a');
    });
  });

  group('mixesDiffer', () {
    test('mixes differ on O2', () {
      expect(mixesDiffer([_tank('a', o2: 32), _tank('b', o2: 21)]), isTrue);
    });

    test('mixes differ on He', () {
      expect(
        mixesDiffer([_tank('a', o2: 21, he: 35), _tank('b', o2: 21, he: 0)]),
        isTrue,
      );
    });

    test('equal mixes do not differ', () {
      expect(mixesDiffer([_tank('a', o2: 32), _tank('b', o2: 32.02)]), isFalse);
    });
  });
}
