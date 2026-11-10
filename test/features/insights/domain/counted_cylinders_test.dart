import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart';
import 'package:submersion/features/insights/domain/counted_cylinders.dart';

DiveTank _tank(
  String id, {
  TankRole role = TankRole.backGas,
  double o2 = 21,
  double he = 0,
  String? computerId,
  String? sourceId,
  List<String>? sharedComputerIds,
}) => DiveTank(
  id: id,
  role: role,
  gasMix: GasMix(o2: o2, he: he),
  computerId: computerId,
  sourceId: sourceId,
  sharedComputerIds: sharedComputerIds,
);

Set<String> _counted(
  List<DiveTank> tanks, {
  String? primarySourceId = 'src-primary',
  String? primaryComputerId = 'primary',
}) => countedCylinderIds(
  tanks,
  primarySourceId: primarySourceId,
  primaryComputerId: primaryComputerId,
);

void main() {
  group('countedCylinderIds', () {
    test('with no primary source every cylinder counts', () {
      expect(
        _counted([
          _tank('a', computerId: 'primary'),
          _tank('b', computerId: 'other'),
        ], primarySourceId: null),
        {'a', 'b'},
      );
    });

    test('the primary recording\'s cylinders always count', () {
      expect(
        _counted([
          _tank('a', role: TankRole.sidemountLeft, computerId: 'primary'),
          _tank('b', role: TankRole.sidemountRight, computerId: 'primary'),
          _tank('c', computerId: null, sourceId: null),
          _tank('d', computerId: 'other', sharedComputerIds: ['primary']),
        ]),
        {'a', 'b', 'c', 'd'},
      );
    });

    test('a stage only another computer logged counts (issue #4420)', () {
      expect(
        _counted([
          _tank('l', role: TankRole.sidemountLeft, computerId: 'primary'),
          _tank('r', role: TankRole.sidemountRight, computerId: 'primary'),
          _tank('s', role: TankRole.stage, o2: 46, computerId: 'garmin'),
        ]),
        {'l', 'r', 's'},
      );
    });

    test('another computer\'s cylinder on a counted gas is a copy', () {
      expect(
        _counted([
          _tank('a', o2: 32, computerId: 'primary'),
          _tank('b', role: TankRole.stage, o2: 32.4, computerId: 'other'),
        ]),
        {'a'},
      );
    });

    test('another computer\'s bottom gas beside the primary\'s is a copy', () {
      // A backup left on air beside a primary on 32%: one cylinder, logged
      // on a stale mix, not a second bottom gas.
      expect(
        _counted([
          _tank('a', o2: 32, computerId: 'primary'),
          _tank('b', computerId: 'other'),
        ]),
        {'a'},
      );
    });

    test('a deco-strength back gas row is not a bottom gas', () {
      // An import without roles labels every cylinder back gas.
      expect(
        _counted([
          _tank('a', computerId: 'primary'),
          _tank('b', o2: 50, computerId: 'other'),
        ]),
        {'a', 'b'},
      );
    });

    test('a cylinder naming no computer belongs to its source', () {
      expect(
        _counted([
          _tank('a', sourceId: 'src-primary'),
          _tank('b', sourceId: 'src-other'),
          _tank('c', role: TankRole.deco, o2: 100, sourceId: 'src-other'),
        ]),
        {'a', 'c'},
      );
    });

    test('two other computers\' copies of one cylinder count once', () {
      expect(
        _counted([
          _tank('a', computerId: 'primary'),
          _tank('b', role: TankRole.stage, o2: 50, computerId: 'c2'),
          _tank('c', role: TankRole.stage, o2: 50, computerId: 'c3'),
        ]),
        {'a', 'b'},
      );
    });

    test('one recording\'s two cylinders on one gas both count', () {
      expect(
        _counted([
          _tank('a', computerId: 'primary'),
          _tank('b', role: TankRole.stage, o2: 50, computerId: 'other'),
          _tank('c', role: TankRole.stage, o2: 50, computerId: 'other'),
        ]),
        {'a', 'b', 'c'},
      );
    });

    test('a primary owning none keeps every other computer\'s cylinder', () {
      expect(
        _counted([
          _tank('a', role: TankRole.sidemountLeft, computerId: 'other'),
          _tank('b', role: TankRole.sidemountRight, computerId: 'other'),
        ]),
        {'a', 'b'},
      );
    });

    test('another computer\'s diluent beside the primary\'s is a copy', () {
      expect(
        _counted([
          _tank(
            'a',
            role: TankRole.diluent,
            o2: 18,
            he: 45,
            computerId: 'primary',
          ),
          _tank('b', role: TankRole.diluent, computerId: 'other'),
          _tank('c', role: TankRole.bailout, o2: 50, computerId: 'other'),
        ]),
        {'a', 'c'},
      );
    });

    test('another computer\'s oxygen beside the primary\'s is a copy', () {
      expect(
        _counted([
          _tank(
            'a',
            role: TankRole.oxygenSupply,
            o2: 100,
            computerId: 'primary',
          ),
          _tank('b', role: TankRole.oxygenSupply, o2: 98, computerId: 'other'),
        ]),
        {'a'},
      );
    });

    test('with a primary naming no computer, a named computer is another '
        'recording', () {
      expect(
        _counted([
          _tank('a', sourceId: 'src-primary'),
          _tank('b', computerId: 'other'),
          _tank('c', role: TankRole.deco, o2: 50, computerId: 'other'),
        ], primaryComputerId: null),
        {'a', 'c'},
      );
    });

    test('another computer\'s back gas beside the primary\'s diluent is a '
        'copy', () {
      // A rebreather dive reads a back gas row as the diluent.
      expect(
        _counted([
          _tank(
            'a',
            role: TankRole.diluent,
            o2: 10,
            he: 50,
            computerId: 'primary',
          ),
          _tank('b', computerId: 'other'),
          _tank('c', role: TankRole.sidemountLeft, computerId: 'other'),
        ]),
        {'a', 'c'},
      );
    });

    test('another computer\'s oxygen-strength back gas beside the primary\'s '
        'oxygen is a copy', () {
      expect(
        _counted([
          _tank(
            'a',
            role: TankRole.oxygenSupply,
            o2: 100,
            computerId: 'primary',
          ),
          _tank('b', o2: 99, computerId: 'other'),
        ]),
        {'a'},
      );
    });
  });
}
